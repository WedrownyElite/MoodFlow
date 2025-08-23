---
name: "\U0001F41B Bug Report"
about: Report a problem or unexpected behavior in MoodFlow
title: "[BUG]"
labels: ''
assignees: ''

---

name: 🐛 Bug Report
description: Report a problem or unexpected behavior in MoodFlow
title: "[Bug]: "
labels: [bug]
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to report a bug! Please fill out the details below so we can fix it quickly.

  - type: input
    id: version
    attributes:
      label: App Version
      description: What version of MoodFlow are you using? (e.g., 1.0.0)
      placeholder: "1.0.0"
    validations:
      required: true

  - type: input
    id: device
    attributes:
      label: Device & OS
      description: Device model and Android version
      placeholder: "Pixel 6, Android 13"
    validations:
      required: true

  - type: textarea
    id: steps
    attributes:
      label: Steps to Reproduce
      description: Explain how we can reproduce the issue.
      placeholder: |
        1. Open the app
        2. Tap on ...
        3. App crashes
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: What did you expect to happen?
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: Actual Behavior
      description: What actually happened instead?
    validations:
      required: true

  - type: textarea
    id: screenshots
    attributes:
      label: Screenshots / Logs
      description: If possible, add screenshots or crash logs to help explain.
      placeholder: "Paste logcat snippet or upload screenshot"
