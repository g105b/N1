{ContenteditableExtension} = require 'nylas-exports'
LinkEditor = require './link-editor'

class LinkManager extends ContenteditableExtension
  @keyCommandHandlers: =>
    "contenteditable:insert-link": @_onInsertLink

  # NOTE: This may be called VERY frequently. The toolbarProps and
  # toolbarState may update on every hover and selection change within the
  # composer area.
  #
  # Must return an object with the form:
  # The onClick method will be passed ({editor, event}) when called.
  @toolbarButtons: ({state}) =>
    [{
      className: "btn-link"
      onClick: => @setState toolbarMode: "edit-link"
      tooltip: "Edit Link"
      iconUrl: null # Defined in the css of btn-link
    }]

  # NOTE: This may be called VERY frequently. The toolbarProps and
  # toolbarState may update on every hover and selection change within the
  # composer area.
  #
  # Return a compoennt and the props for that component to put in the
  # toolbar.
  #
  # Must return an object with the form:
  #
  # {
  #   component:
  #   props:
  # }
  @toolbarComponent: ({state}) =>
    if @_isInteractingWithLink
      component = LinkEditor
    else
      component = null
    return {component, props}

  @_onInsertLink: ({editor, event}) ->
    if editor.currentSelection.isCollapsed
      html = "&nbsp;<n1-prompt-link>link text</n1-prompt-link>&nbsp;"
      editor.insertHTML(html, selectInsertion: true)
    else
      editor.wrapSelection("n1-prompt-link")

  _onSaveUrl: (url, linkToModify) =>
    @props.atomicEdit ({editor}) ->
      if linkToModify?
        equivalentNode = DOMUtils.findSimilarNodes(editor.rootNode, linkToModify)?[0]
        return unless equivalentNode?
        equivalentLinkText = DOMUtils.findFirstTextNode(equivalentNode)
        return if linkToModify.getAttribute?('href')?.trim() is url.trim()
        toSelect = equivalentLinkText
      else
        # When atomicEdit gets run, the exportedSelection is already restored to
        # the last saved exportedSelection state. Any operation we perform will
        # apply to the last saved exportedSelection state.
        toSelect = null

      if url.trim().length is 0
        if toSelect then editor.select(toSelect).unlink()
        else editor.unlink()
      else
        if toSelect then editor.select(toSelect).createLink(url)
        else editor.createLink(url)

module.exports = LinkManager
