{DOMUtils, ContenteditableExtension} = require 'nylas-exports'

class LinkManager extends ContenteditableExtension
  @keyCommandHandlers: =>
    "contenteditable:insert-link": @_onInsertLink

  @_onInsertLink: ({editor, event}) ->

module.exports = LinkManager
