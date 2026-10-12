#!/usr/bin/env python3
"""Validate Gatefall's executable story without changing canon.

Authority: Gatefall-Notes Vault. The game JSON is an implementation mirror.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "gatefall_dialogue_engine" / "data"
IDS = ("faelen", "kess", "momo", "thora", "dana")


def audit():
    errors = []
    warnings = []
    count = 0
    for character in IDS:
        route_path = DATA / f"{character}_route.json"
        route = json.loads(route_path.read_text(encoding="utf-8"))
        beats = route["beats"]
        if route.get("character_id") != character or len(beats) != 7:
            errors.append(f"{character}: expected seven beats and matching character_id")
        beat_ids = {b["beat_id"] for b in beats}
        if len(beat_ids) != len(beats) or sorted(b["order"] for b in beats) != list(range(7)):
            errors.append(f"{character}: beat ids/orders must be unique and 0..6")
        for beat in beats:
            for prerequisite in beat.get("unlock_conditions", {}).get("requires_beats_complete", []):
                if prerequisite not in beat_ids:
                    errors.append(f"{character}: missing prerequisite {prerequisite}")
            ref = beat["scene_ref"]
            scene_path = DATA / ref.removeprefix("data/")
            if not scene_path.is_file():
                errors.append(f"{character}: scene missing: {ref}")
                continue
            scene = json.loads(scene_path.read_text(encoding="utf-8"))
            nodes = scene["nodes"]
            start = scene["start_node"]
            if scene.get("scene_id") != beat["beat_id"]:
                errors.append(f"{ref}: scene_id does not match beat")
            if start not in nodes:
                errors.append(f"{ref}: start_node does not exist")
                continue
            count += 1
            reached = set()
            stack = [start]
            while stack:
                node_id = stack.pop()
                if node_id in reached:
                    continue
                node = nodes.get(node_id)
                if node is None:
                    errors.append(f"{ref}: dangling link to {node_id}")
                    continue
                reached.add(node_id)
                if node.get("next") is not None:
                    stack.append(node["next"])
                for choice in node.get("choices", []):
                    stack.append(choice["next"])
                if not node.get("end_scene") and not node.get("next") and not node.get("choices"):
                    errors.append(f"{ref}: nonterminal dead end {node_id}")
            if not any(nodes[node].get("end_scene") for node in reached):
                errors.append(f"{ref}: no reachable ending")
            missing = set(nodes) - reached
            if missing:
                warnings.append(f"{ref}: {len(missing)} unreachable nodes: {', '.join(sorted(missing)[:8])}")
        endings = {x["ending_id"] for x in route["endings"]}
        if endings != {f"{character}_{x}" for x in ("true", "lost", "bittersweet")}:
            errors.append(f"{character}: expected true/lost/bittersweet ending ids")
    if count != 35:
        errors.append(f"Expected 35 valid scenes, found {count}")
    return errors, warnings, count


if __name__ == "__main__":
    errors, warnings, count = audit()
    print(f"Audited {count} scenes across {len(IDS)} character routes")
    for item in warnings:
        print("WARNING:", item)
    for item in errors:
        print("ERROR:", item)
    raise SystemExit(bool(errors))
