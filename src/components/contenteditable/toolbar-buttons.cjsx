React = require 'react/addons'
{RetinaImg} = require 'nylas-component-kit'

# This component renders buttons and is the default view in the
# FloatingToolbar.
#
# Extensions that implement `toolbarButtons` can get their buttons added
# in.
#
# The {EmphasisFormatting} extension is an example of one that implements this spec.
class ToolbarButtons extends React.Component
  @displayName = "ToolbarButtons"

  @propTypes:
    # Either "edit-link" or "buttons". Determines whether we're showing
    # edit buttons or the link editor
    mode: React.PropTypes.string

    # Declares what buttons should appear in the toolbar. An array of
    # config objects.
    extensions: React.PropTypes.array

  @defaultProps:
    mode: "buttons"
    extensions: []

  constructor: (@props) ->
    @state =
      componentWidth: 0
      # urlInputValue: @_initialUrl() ? ""

  componentWillReceiveProps: (nextProps) =>
    @setState
      urlInputValue: @_initialUrl(nextProps)

  componentDidUpdate: =>
    if @props.mode is "edit-link" and not @props.linkToModify
      React.findDOMNode(@refs.urlInput).focus()

  render: =>
    @_renderButtons()
    # <div ref="floatingToolbar"
    #      className={@_toolbarClasses()} style={@_toolbarStyles()}>
    #   <div className="toolbar-pointer" style={@_toolbarPointerStyles()}></div>
    #   {@_toolbarType()}
    # </div>

  _toolbarButtonConfigs: ->
    # atomicEditWrap = (command) =>
    #   (event) =>
    #     @props.atomicEdit((({editor}) -> editor[command]()), event)
    #
    extensionButtonConfigs = []
    @props.extensions.forEach (ext) ->
      config = ext.toolbarButtons?()
      extensionButtonConfigs.push(config) if config?

  _renderButtons: =>
    @_toolbarButtonConfigs().map (config, i) ->
      if (config.iconUrl ? "").length > 0
        icon = <RetinaImg mode={RetinaImg.Mode.ContentIsMask}
                          url="#{toolbarItem.iconUrl}" />
      else icon = ""

      <button className="btn toolbar-btn #{config.className ? ''}"
              key={"btn-#{i}"}
              onClick={config.onClick}
              title="#{config.tooltip}">{icon}</button>

  # _toolbarLeft: =>
  #   CONTENT_PADDING = @props.contentPadding ? 15
  #   max = @props.editAreaWidth - @_toolbarWidth() - CONTENT_PADDING
  #   left = Math.min(Math.max(@props.left - @_toolbarWidth()/2, CONTENT_PADDING), max)
  #   return left
  #
  # _toolbarPointerStyles: =>
  #   CONTENT_PADDING = @props.contentPadding ? 15
  #   POINTER_WIDTH = 6 + 2 #2px of border-radius
  #   max = @props.editAreaWidth - CONTENT_PADDING
  #   min = CONTENT_PADDING
  #   absoluteLeft = Math.max(Math.min(@props.left, max), min)
  #   relativeLeft = absoluteLeft - @_toolbarLeft()
  #
  #   left = Math.max(Math.min(relativeLeft, @_toolbarWidth()-POINTER_WIDTH), POINTER_WIDTH)
  #   styles =
  #     left: left
  #   return styles
  #
  # _toolbarWidth: =>
  #   # We can't calculate the width of the floating toolbar declaratively
  #   # because it hasn't been rendered yet. As such, we'll keep the width
  #   # fixed to make it much eaier.
  #   TOOLBAR_BUTTONS_WIDTH = 114#px
  #   TOOLBAR_URL_WIDTH = 210#px
  #
  #   # If we have a long link, we want to make a larger text area. It's not
  #   # super important to get the length exactly so let's just get within
  #   # the ballpark by guessing charcter lengths
  #   WIDTH_PER_CHAR = 11
  #   max = @props.editAreaWidth - (@props.contentPadding ? 15)*2
  #
  #   if @props.mode is "buttons"
  #     return TOOLBAR_BUTTONS_WIDTH
  #   else if @props.mode is "edit-link"
  #     url = @_initialUrl()
  #     if url?.length > 0
  #       fullWidth = Math.max(Math.min(url.length * WIDTH_PER_CHAR, max), TOOLBAR_URL_WIDTH)
  #       return fullWidth
  #     else
  #       return TOOLBAR_URL_WIDTH
  #   else
  #     return TOOLBAR_BUTTONS_WIDTH

  # _toolbarClasses: =>
  #   classes = {}
  #   classes[@props.pos] = true
  #   classNames _.extend classes,
  #     "floating-toolbar": true
  #     "toolbar": true
  #     "toolbar-visible": @props.visible

  # _toolbarStyles: =>
  #   styles =
  #     left: @_toolbarLeft()
  #     top: @props.top
  #     width: @_toolbarWidth()
  #   return styles
  #
  # _toolbarType: =>
  #   if @props.mode is "buttons" then @_renderButtons()
  #   else if @props.mode is "edit-link" then @_renderLink()
  #   else return <div></div>

module.exports = ToolbarButtons
