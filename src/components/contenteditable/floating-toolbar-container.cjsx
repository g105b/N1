_ = require 'underscore'
React = require 'react'

{Utils, DOMUtils, ExtensionRegistry} = require 'nylas-exports'

FloatingToolbar = require './floating-toolbar'

# This is responsible for the logic required to position a floating
# toolbar
class FloatingToolbarContainer extends React.Component
  @displayName: "FloatingToolbarContainer"

  @propTypes:
    # We are passed in the Contenteditable's `atomicEdit` mutator
    # function. This is the safe way to request updates in the
    # contenteditable. It will pass the editable DOM node and the
    # exportedSelection object plus any extra args (like DOM event
    # objects) to the callback
    atomicEdit: React.PropTypes.func

  @innerPropTypes:
    links: React.PropTypes.array
    dragging: React.PropTypes.bool
    doubleDown: React.PropTypes.bool
    editableNode: React.PropTypes.object
    editableFocused: React.PropTypes.bool
    exportedSelection: React.PropTypes.object

  constructor: (@props) ->
    @state =
      toolbarTop: 0
      toolbarMode: "buttons"
      toolbarLeft: 0
      toolbarPos: "above"
      editAreaWidth: 9999 # This will get set on first exportedSelection
      toolbarVisible: false
      linkHoveringOver: null
    @innerProps =
      links: []
      dragging: false
      doubleDown: false
      editableNode: null
      editableFocused: null
      exportedSelection: null

  shouldComponentUpdate: (nextProps, nextState) ->
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  # Some properties (like whether we're dragging or clicking the mouse)
  # should in a strict-sense be props, but update in a way that's not
  # performant to got through the full React re-rendering cycle,
  # especially given the complexity of the composer component.
  #
  # We call these performance-optimized props & state innerProps and
  # innerState.
  componentWillReceiveInnerProps: (nextInnerProps={}) =>
    if "links" of nextInnerProps
      @_refreshLinkHoverListeners(nextInnerProps["links"])

    fullProps = _.extend(@props, nextInnerProps)
    @setState(@_getStateFromProps(fullProps))

    @innerProps = _.extend @innerProps, nextInnerProps

  componentWillReceiveProps: (nextProps) =>
    fullProps = _.extend(@innerProps, nextProps)
    @setState(@_getStateFromProps(fullProps))

  # The context menu, when activated, needs to make sure that the toolbar
  # is closed. Unfortunately, since there's no onClose callback for the
  # context menu, we can't hook up a reliable declarative state to the
  # menu. We break our declarative pattern in this one case.
  forceClose: ->
    @setState toolbarVisible: false

  render: ->
    <FloatingToolbar
      ref="floatingToolbar"
      top={@state.toolbarTop}
      left={@state.toolbarLeft}
      pos={@state.toolbarPos}
      mode={@state.toolbarMode}
      visible={@state.toolbarVisible}
      onSaveUrl={@_onSaveUrl}
      onMouseEnter={@_onEnterToolbar}
      onChangeMode={@_onChangeMode}
      onMouseLeave={@_onLeaveToolbar}
      linkToModify={@state.linkToModify}
      buttonConfigs={@_toolbarButtonConfigs()}
      editAreaWidth={@state.editAreaWidth}
      contentPadding={@CONTENT_PADDING}
      onDoneWithLink={@_onDoneWithLink} />

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

  # We setup the buttons that the Toolbar should have as a combination of
  # core actions and user-defined plugins. The FloatingToolbar simply
  # renders them.
  _toolbarButtonConfigs: ->
    atomicEditWrap = (command) =>
      (event) =>
        @props.atomicEdit((({editor}) -> editor[command]()), event)

    extensionButtonConfigs = []
    ExtensionRegistry.Composer.extensions().forEach (ext) ->
      config = ext.composerToolbar?()
      extensionButtonConfigs.push(config) if config?

    return [
      {
        className: "btn-bold"
        onClick: atomicEditWrap("bold")
        tooltip: "Bold"
        iconUrl: null # Defined in the css of btn-bold
      }
      {
        className: "btn-italic"
        onClick: atomicEditWrap("italic")
        tooltip: "Italic"
        iconUrl: null # Defined in the css of btn-italic
      }
      {
        className: "btn-underline"
        onClick: atomicEditWrap("underline")
        tooltip: "Underline"
        iconUrl: null # Defined in the css of btn-underline
      }
      {
        className: "btn-link"
        onClick: => @setState toolbarMode: "edit-link"
        tooltip: "Edit Link"
        iconUrl: null # Defined in the css of btn-link
      }
    ].concat(extensionButtonConfigs)

  # A user could be done with a link because they're setting a new one, or
  # clearing one, or just canceling.
  _onDoneWithLink: =>
    @componentWillReceiveInnerProps linkHoveringOver: null
    @setState
      toolbarMode: "buttons"
      toolbarVisible: false
    return

  # We want the toolbar's state to be declaratively defined from other
  # states.
  _getStateFromProps: (props = (_.extend({}, @props, @innerProps))) =>
    return {} if @_mouseInUse(props)

    newState = {
      toolbarMode: @_toolbarMode(props)
      linkToModify: props.linkHoveringOver
      toolbarVisible: @_toolbarVisible(props)
    }

    if newState.toolbarVisible
      _.extend(newState, @_getPositionData(props))

    return newState

    # return if props.dragging or (props.doubleDown and not @state.toolbarVisible)
    # if props.toolbarFocus
    #   @setState toolbarVisible: true
    #   return

    # if @_shouldHideToolbar(props)
    #   @setState
    #     toolbarVisible: false
    #     toolbarMode: "buttons"
    #   return

    # if props.linkHoveringOver
    #   url = props.linkHoveringOver.getAttribute('href')
    #   rect = props.linkHoveringOver.getBoundingClientRect()
    #   [left, top, editAreaWidth, toolbarPos] = @_getToolbarPos(rect)
    #   @setState
    #     toolbarVisible: true
    #     toolbarMode: "edit-link"
    #     toolbarTop: top
    #     toolbarLeft: left
    #     toolbarPos: toolbarPos
    #     linkToModify: props.linkHoveringOver
    #     editAreaWidth: editAreaWidth
    # else
    #   # return if @state.toolbarMode is "edit-link"
    #   rect = DOMUtils.getRangeInScope(props.editableNode)?.getBoundingClientRect()
    #   if not rect or DOMUtils.isEmptyBoundingRect(rect)
    #     @setState
    #       toolbarVisible: false
    #       toolbarMode: "buttons"
    #   else
    #     [left, top, editAreaWidth, toolbarPos] = @_getToolbarPos(rect)
    #     @setState
    #       toolbarVisible: true
    #       toolbarTop: top
    #       toolbarLeft: left
    #       toolbarPos: toolbarPos
    #       linkToModify: null
    #       editAreaWidth: editAreaWidth

  # _shouldHideToolbar: (props) ->
  #   return false if @state.toolbarMode is "edit-link"
  #   return false if props.linkHoveringOver
  #   return not props.editableFocused or
  #          not props.exportedSelection or
  #          props.exportedSelection.isCollapsed

  _toolbarVisible: (props) ->
    if @_focusedInToolbar()
      return true
    else
      if props.exportedSelection.isCollapsed
        return @_isInteractingWithLink(props)
      else
        return true

  _isInteractingWithLink: (props) ->
    return props.linkHoveringOver or @_isSelectingLink(props)

  _toolbarMode: (props) ->
    if @_isInteractingWithLink(props) then "edit-link" else "buttons"

  _isSelectingLink: (props) ->
    anode = props.exportedSelection.anchorNode
    fnode = props.exportedSelection.focusNode

    testForATag = ->
      DOMUtils.closest(anode, 'a') and DOMUtils.closest(fnode, 'a')

    testForCustomTag = ->
      tag = "n1-prompt-link"
      DOMUtils.closest(anode, tag) and DOMUtils.closest(fnode, tag)

    return testForATag() or testForCustomTag()

  _focusedInToolbar: =>
    React.findDOMNode(@)?.contains(document.activeElement)

  _mouseInUse: ->
    props.dragging or (props.doubleDown and not @state.toolbarVisible)

  _refreshLinkHoverListeners: (newLinks = @innerProps.links) ->
    @_teardownLinkHoverListeners()
    @_links = {}
    links = Array.prototype.slice.call(newLinks)
    links.forEach (link) =>
      link.hoverId = Utils.generateTempId()
      @_links[link.hoverId] = {}

      context = this
      enterListener = (event) ->
        link = this
        context._onEnterLink.call(context, link, event)
      leaveListener = (event) ->
        link = this
        context._onLeaveLink.call(context, link, event)

      link.addEventListener "mouseenter", enterListener
      link.addEventListener "mouseleave", leaveListener
      @_links[link.hoverId].link = link
      @_links[link.hoverId].enterListener = enterListener
      @_links[link.hoverId].leaveListener = leaveListener

  _onEnterLink: (link, event) =>
    HOVER_IN_DELAY = 250
    @_clearLinkTimeouts()
    @_links[link.hoverId].enterTimeout = setTimeout =>
      @componentWillReceiveInnerProps linkHoveringOver: link
    , HOVER_IN_DELAY

  _onLeaveLink: (link, event) =>
    HOVER_OUT_DELAY = 500
    @_clearLinkTimeouts()
    @_links[link.hoverId].leaveTimeout = setTimeout =>
      @componentWillReceiveInnerProps linkHoveringOver: null
    , HOVER_OUT_DELAY

  _onEnterToolbar: (event) =>
    clearTimeout(@_clearTooltipTimeout) if @_clearTooltipTimeout?

    # 1. Hover over a link until the toolbar appears.
    # 2. The toolbar's link input will be UNfocused
    # 3. Moving the mouse off the link and over the toolbar will cause
    # _onLinkLeave to fire. Before the `leaveTimeout` fires, clear it
    # since our mouse has safely made it to the tooltip.
    @_clearLinkTimeouts()

  # Called when the mouse leaves the "edit-link" mode toolbar.
  #
  # NOTE: The leave callback does NOT get called if the user has the input
  # field focused. We don't want the make the box dissapear under the user
  # when they're typing.
  _onLeaveToolbar: (event) =>
    HOVER_OUT_DELAY = 250
    @_clearTooltipTimeout = setTimeout =>
      # If we've hovered over a link until the toolbar appeared, then
      # `linkHoverOver` will be set to that link. When we move the mouse
      # onto the toolbar, `_onEnterToolbar` will make sure that
      # `linkHoveringOver` doesn't get cleared. If we then move our mouse
      # off of the toolbar, we need to remember to clear the hovering
      # link.
      @componentWillReceiveInnerProps linkHoveringOver: null
    , 250

  _clearLinkTimeouts: ->
    for hoverId, linkData of @_links
      clearTimeout(linkData.enterTimeout) if linkData.enterTimeout?
      clearTimeout(linkData.leaveTimeout) if linkData.leaveTimeout?

  _teardownLinkHoverListeners: =>
    for hoverId, linkData of @_links
      clearTimeout linkData.enterTimeout
      clearTimeout linkData.leaveTimeout
      linkData.link.removeEventListener "mouseenter", linkData.enterListener
      linkData.link.removeEventListener "mouseleave", linkData.leaveListener
    @_links = {}

  CONTENT_PADDING: 15

  _getPositionData: (props) =>
    editableNode = props.editableNode

    if props.linkHoveringOver
      referenceRect = props.linkHoveringOver.getBoundingClientRect()
    else
      referenceRect = DOMUtils.getRangeInScope(editableNode)?.getBoundingClientRect()

    if not editableNode or not referenceRect or DOMUtils.isEmptyBoundingRect(referenceRect)
      return {toolbarTop: 0, toolbarLeft: 0, editAreaWidth: 0, toolbarPos: 'above'}

    TOP_PADDING = 10

    BORDER_RADIUS_PADDING = 15

    editArea = editableNode.getBoundingClientRect()

    calcLeft = (referenceRect.left - editArea.left) + referenceRect.width/2
    calcLeft = Math.min(Math.max(calcLeft, @CONTENT_PADDING+BORDER_RADIUS_PADDING), editArea.width - BORDER_RADIUS_PADDING)

    calcTop = referenceRect.top - editArea.top - 48
    toolbarPos = "above"
    if calcTop < TOP_PADDING
      calcTop = referenceRect.top - editArea.top + referenceRect.height + TOP_PADDING + 4
      toolbarPos = "below"

    return {
      toolbarTop: calcTop
      toolbarLeft: calcLeft
      editAreaWidth: editArea.width
      toolbarPos: toolbarPos
    }

module.exports = FloatingToolbarContainer
