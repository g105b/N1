{Actions, ContenteditableExtension} = require 'nylas-exports'

class LinkManager extends ContenteditableExtension
  @keyCommandHandlers: =>
    "contenteditable:insert-link": @_onInsertLink

  @_onInsertLink: ({editor, event}) ->
    if editor.currentSelection.isCollapsed
      html = "&nbsp;<n1-prompt-link>link text</n1-prompt-link>&nbsp;"
      editor.insertHTML(html, selectInsertion: true)
    else
      editor.wrapSelection("n1-prompt-link")

module.exports = LinkManager
