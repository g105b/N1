{ContenteditableExtension} = require 'nylas-exports'

# This provides the default baisc formatting options for the
# Contenteditable using the declarative extension API.
class BasicFormatting extends ContenteditableExtension
  @toolbarButtons: ({state}) => [
    {
      className: "btn-bold"
      onClick: @_onBold
      tooltip: "Bold"
      iconUrl: null # Defined in the css of btn-bold
    }
    {
      className: "btn-italic"
      onClick: @_onItalic
      tooltip: "Italic"
      iconUrl: null # Defined in the css of btn-italic
    }
    {
      className: "btn-underline"
      onClick: @_onUnderline
      tooltip: "Underline"
      iconUrl: null # Defined in the css of btn-underline
    }
  ]

  @_onBold: ({editor, event}) -> editor.bold()

  @_onItalic: ({editor, event}) -> editor.italic()

  @_onUnderline: ({editor, event}) -> editor.underline()

  # None of the basic formatting buttons need a custom component.
  # We can either return `null` or return the requsted object with no
  # component.
  @toolbarComponent: ({state}) =>
    component: null,
    props: {}

module.exports = BasicFormatting
