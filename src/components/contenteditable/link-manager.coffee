{DOMUtils, ContenteditableExtension} = require 'nylas-exports'
LinkEditor = require './link-editor'

class LinkManager extends ContenteditableExtension
  @keyCommandHandlers: =>
    "contenteditable:insert-link": @_onInsertLink

  @toolbarButtons: ({toolbarState}) =>
    [{
      className: "btn-link"
      onClick: @_onInsertLink
      tooltip: "Edit Link"
      iconUrl: null # Defined in the css of btn-link
    }]

  @toolbarComponentData: ({toolbarState}) =>
    return null if toolbarState.dragging or toolbarState.doubleDown
    linkHoveringOver = DOMUtils.closest(toolbarState.hoveringOver, 'a')
    if @_isInteractingWithLink(linkHoveringOver, toolbarState)
      return {
        component: LinkEditor
        props:
          onSaveUrl: @_onSaveUrl
          onDoneWithLink: @_onDoneWithLink
          linkToModify: linkHoveringOver
        locationRef: null
        width: 100
      }
    else return null

  @_isInteractingWithLink: (linkHoveringOver, toolbarState) ->
    return linkHoveringOver or @_isSelectingLink(toolbarState)

  @_isSelectingLink: (toolbarState) ->
    anode = toolbarState.exportedSelection.anchorNode
    fnode = toolbarState.exportedSelection.focusNode

    testForATag = ->
      DOMUtils.closest(anode, 'a') and DOMUtils.closest(fnode, 'a')

    testForCustomTag = ->
      tag = "n1-prompt-link"
      DOMUtils.closest(anode, tag) and DOMUtils.closest(fnode, tag)

    return testForATag() or testForCustomTag()

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
