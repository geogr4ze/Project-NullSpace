# Development standards

- Preserve game mechanics, public interfaces, scene references, and resource paths.
- Add a `##` specification above every named function, including helpers and
  lifecycle callbacks. Explain parameters, requirements, returns, side effects,
  failure cases and relevant invariants. Update it when behavior changes.
- Aim for 80–100 characters per line; avoid exceeding 120 except for unavoidable
  literals or generated data. Use multiline conditions, arrays and dictionaries.
- Use descriptive names, explicit GDScript types where appropriate, consistent
  tab indentation, and comments that explain design decisions.
- Keep functions cohesive; avoid compressed one-liners and unnecessary nesting.
- Keep credentials, machine-specific settings and generated editor files out of Git.
- Run the project's gameplay and automated tests before merging behavioral changes.
  Report any test or verification limitations.
