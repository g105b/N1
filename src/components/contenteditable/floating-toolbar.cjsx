_ = require 'underscore'
classNames = require 'classnames'
React = require 'react'

{Utils, DOMUtils, ExtensionRegistry} = require 'nylas-exports'

ToolbarButtons = require './toolbar-buttons'

# Positions and renders a FloatingToolbar in the composer.
#
# By default, it will display the {ToolbarButtons} component.
#
# If a {ContenteditableExtension} implements `toolbarComponent`, and the
# appropriate declarative conditions are met, then that component will be
# displayed instead.
class FloatingToolbar extends React.Component
  @displayName: "FloatingToolbar"

  @propTypes:
    # We are passed in the Contenteditable's `atomicEdit` mutator
    # function. This is the safe way to request updates in the
    # contenteditable. It will pass the editable DOM node and the
    # exportedSelection object plus any extra args (like DOM event
    # objects) to the callback
    atomicEdit: React.PropTypes.func

    # We are passed an array of Extensions. Those that implement the
    # `toolbarButton` and/or the `toolbarComponent` methods will be
    # injected into the Toolbar.
    extensions: React.PropTypes.array

  @defaultProps:
    extensions: []

  # Every time the `innerProps` of the `Contenteditable` change, we get
  # passed new ones.
  @innerPropTypes:
    dragging: React.PropTypes.bool
    doubleDown: React.PropTypes.bool
    hoveringOver: React.PropTypes.object
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
    @innerProps =
      dragging: false
      doubleDown: false
      hoveringOver: null
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
    fullProps = _.extend(@props, nextInnerProps)
    @innerProps = _.extend @innerProps, nextInnerProps
    @setState(@_getStateFromProps(fullProps))

  componentWillReceiveProps: (nextProps) =>
    fullProps = _.extend(@innerProps, nextProps)
    @setState(@_getStateFromProps(fullProps))

  # The context menu, when activated, needs to make sure that the toolbar
  # is closed. Unfortunately, since there's no onClose callback for the
  # context menu, we can't hook up a reliable declarative state to the
  # menu. We break our declarative pattern in this one case.
  forceClose: ->
    @setState toolbarVisible: false

  _combinedState: ->
    return _.extend {}, @state, @props, @innerProps

  render: ->
    <div className="floating-toolbar-container">
      <div ref="floatingToolbar"
           className={@_toolbarClasses()}
           style={@_toolbarStyles()}>
        <div className="toolbar-pointer"
             style={@_toolbarPointerStyles()}></div>
        {@_renderFloatingComponent()}
      </div>
    </div>

  # Defaults to `ToolbarButtons`
  _renderFloatingComponent: ->
    Component = ToolbarButtons

    defaultProps = {extensions: @props.extensions}
    extensionProps = {}

    for extension in @props.extensions
      params = extension.toolbarComponent?(@_combinedState()) ? {}
      if params.component
        Component = params.component
        extensionProps = params.props ? {}

    props = _.extend(defaultProps, extensionProps)
    <Component {...props} />

  # We want the toolbar's state to be declaratively defined from other
  # states.
  _getStateFromProps: (props = (_.extend({}, @props, @innerProps))) =>
    return {} if @_mouseInUse(props)

    newState = {
      toolbarMode: @_toolbarMode(props)
      linkToModify: props.hoveringOver
      toolbarVisible: @_toolbarVisible(props)
    }

    if newState.toolbarVisible
      _.extend(newState, @_getPositionData(props))

    return newState

  _toolbarVisible: (props) ->
    if @_focusedInToolbar()
      return true
    else
      if props.exportedSelection.isCollapsed
        return @_isInteractingWithLink(props)
      else
        return true

  _isInteractingWithLink: (props) ->
    return props.hoveringOver or @_isSelectingLink(props)

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

  CONTENT_PADDING: 15

  _getPositionData: (props) =>
    editableNode = props.editableNode

    if props.hoveringOver
      referenceRect = props.hoveringOver.getBoundingClientRect()
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

  _toolbarClasses: =>
    classes = {}
    classes[@state.toolbarPos] = true
    classNames _.extend classes,
      "floating-toolbar": true
      "toolbar": true
      "toolbar-visible": @state.toolbarVisible

  _toolbarStyles: =>
    styles =
      left: @_toolbarLeft()
      top: @state.toolbarTop
      width: @_toolbarWidth()
    return styles

  _toolbarLeft: =>
    max = @state.editAreaWidth - @_toolbarWidth() - @CONTENT_PADDING
    left = Math.min(Math.max(@state.toolbarLeft - @_toolbarWidth()/2, @CONTENT_PADDING), max)
    return left

  _toolbarPointerStyles: =>
    POINTER_WIDTH = 6 + 2 #2px of border-radius
    max = @state.editAreaWidth - @CONTENT_PADDING
    min = @CONTENT_PADDING
    absoluteLeft = Math.max(Math.min(@state.toolbarLeft, max), min)
    relativeLeft = absoluteLeft - @_toolbarLeft()

    left = Math.max(Math.min(relativeLeft, @_toolbarWidth()-POINTER_WIDTH), POINTER_WIDTH)
    styles =
      left: left
    return styles

  ## TODO We need to determine the width somehow.
  _toolbarWidth: =>
    return 150
    # # We can't calculate the width of the floating toolbar declaratively
    # # because it hasn't been rendered yet. As such, we'll keep the width
    # # fixed to make it much eaier.
    # TOOLBAR_BUTTONS_WIDTH = 114#px
    # TOOLBAR_URL_WIDTH = 210#px
    #
    # # If we have a long link, we want to make a larger text area. It's not
    # # super important to get the length exactly so let's just get within
    # # the ballpark by guessing charcter lengths
    # WIDTH_PER_CHAR = 11
    # max = @state.editAreaWidth - @CONTENT_PADDING*2
    #
    # if @state.toolbarMode is "buttons"
    #   return TOOLBAR_BUTTONS_WIDTH
    # else if @state.toolbarMode is "edit-link"
    #   url = @_initialUrl()
    #   if url?.length > 0
    #     fullWidth = Math.max(Math.min(url.length * WIDTH_PER_CHAR, max), TOOLBAR_URL_WIDTH)
    #     return fullWidth
    #   else
    #     return TOOLBAR_URL_WIDTH
    # else
    #   return TOOLBAR_BUTTONS_WIDTH

module.exports = FloatingToolbar

  # We setup the buttons that the Toolbar should have as a combination of
  # core actions and user-defined plugins. The ToolbarButtons simply
  # renders them.
  # _toolbarButtonConfigs: ->
  #   # atomicEditWrap = (command) =>
  #   #   (event) =>
  #   #     @props.atomicEdit((({editor}) -> editor[command]()), event)
  #   #
  #   extensionButtonConfigs = []
  #   ExtensionRegistry.Composer.extensions().forEach (ext) ->
  #     config = ext.composerToolbar?()
  #     extensionButtonConfigs.push(config) if config?
  #
  #   return [
  #     # {
  #     #   className: "btn-bold"
  #     #   onClick: atomicEditWrap("bold")
  #     #   tooltip: "Bold"
  #     #   iconUrl: null # Defined in the css of btn-bold
  #     # }
  #     # {
  #     #   className: "btn-italic"
  #     #   onClick: atomicEditWrap("italic")
  #     #   tooltip: "Italic"
  #     #   iconUrl: null # Defined in the css of btn-italic
  #     # }
  #     # {
  #     #   className: "btn-underline"
  #     #   onClick: atomicEditWrap("underline")
  #     #   tooltip: "Underline"
  #     #   iconUrl: null # Defined in the css of btn-underline
  #     # }
  #     # {
  #     #   className: "btn-link"
  #     #   onClick: => @setState toolbarMode: "edit-link"
  #     #   tooltip: "Edit Link"
  #     #   iconUrl: null # Defined in the css of btn-link
  #     # }
  #   ].concat(extensionButtonConfigs)


    # <ToolbarButtons
    #   ref="floatingToolbar"
    #   top={@state.toolbarTop}
    #   left={@state.toolbarLeft}
    #   pos={@state.toolbarPos}
    #   visible={@state.toolbarVisible}
    #   component={@state.toolbarComponent}
    #   editAreaWidth={@state.editAreaWidth}
    #   contentPadding={@CONTENT_PADDING} />
    #
      # buttonConfigs={@_toolbarButtonConfigs()}

      # mode={@state.toolbarMode}
      # onSaveUrl={@_onSaveUrl}
      # onChangeMode={@_onChangeMode}
      # linkToModify={@state.linkToModify}
