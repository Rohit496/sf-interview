# Classification Edge Cases

## Formula Fields vs Trigger-Calculated Fields
- When user says "automatically recalculate" it could be formula or trigger
- If user explicitly says "when X is updated, recalculate Y" -> trigger (before context, no DML needed)
- If it's a pure derivation with no conditional logic -> formula field is simpler (admin work)
- In this project: user wanted trigger-based recalculation, classified as dev work

## Checkbox "Flag" Fields
- Creating the field metadata = admin work
- Setting the field value via automation = dev work (if trigger) or admin work (if flow)
