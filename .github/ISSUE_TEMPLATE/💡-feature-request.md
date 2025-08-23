---
name: "\U0001F4A1 Feature Request"
about: Suggest a new feature or improvement for MoodFlow
title: "[REQUEST]"
labels: ''
assignees: ''

---

name: 💡 Feature Request
description: Suggest a new feature or improvement for MoodFlow
title: "[Feature]: "
labels: [enhancement]
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        Have an idea to make MoodFlow better? Awesome! Please share the details below.

  - type: textarea
    id: description
    attributes:
      label: Feature Description
      description: What should we add or improve?
      placeholder: "I'd like MoodFlow to have a dark mode toggle..."

  - type: textarea
    id: motivation
    attributes:
      label: Why is this useful?
      description: Tell us why this feature would improve the app for you or others.
      placeholder: "It would help people track moods at night without straining eyes."

  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives or Workarounds
      description: Are there other solutions you’ve tried or considered?
      placeholder: "I currently adjust my phone’s brightness manually."

  - type: dropdown
    id: priority
    attributes:
      label: Priority
      description: How important is this feature to you?
      options:
        - 🚀 Must-have
        - 👍 Nice-to-have
        - 🤷 Just an idea
