React = require 'react/addons'
{RegExpUtils} = require 'nylas-exports'

class LinkEditor extends React.Component
  @displayName = "LinkEditor"

  @propTypes:
    # A callback function we use to save the URL to the Contenteditable
    onSaveUrl: React.PropTypes.func

    # The current DOM link we are modifying
    linkToModify: React.PropTypes.object

    # A callback used when a link has been cancled, completed, or escaped
    # from. Used to notify our parent to switch modes.
    onDoneWithLink: React.PropTypes.func

  constructor: (@props) ->
    @state =
      urlInputValue: @_initialUrl() ? ""

  componentWillReceiveProps: (newProps) ->
    @setState urlInputValue: @_initialUrl(newProps)

  componentDidMount: ->
    if @props.focusOnMount
      React.findDOMNode(@refs["urlInput"]).focus()

  render: =>
    removeBtn = ""
    withRemove = ""
    if @_initialUrl()
      withRemove = "with-remove"
      removeBtn = <button className="btn btn-icon"
                          ref="removeBtn"
                          onMouseDown={@_removeUrl}><i className="fa fa-times"></i></button>

    <div className="toolbar-new-link">
      <i className="fa fa-link preview-btn-icon"></i>
      <input type="text"
             ref="urlInput"
             value={@state.urlInputValue}
             onBlur={@_onBlur}
             onKeyDown={@_detectEscape}
             onKeyPress={@_saveUrlOnEnter}
             onChange={@_onInputChange}
             className="floating-toolbar-input #{withRemove}"
             placeholder="Paste or type a link" />
      <button className="btn btn-icon"
              onKeyDown={@_detectEscape}
              onKeyPress={@_saveUrlOnEnter}
              onMouseDown={@_saveUrl}><i className="fa fa-check"></i></button>
      {removeBtn}
    </div>

  # Clicking the save or remove buttons will take precendent over simply
  # bluring the field.
  _onBlur: (event) =>
    targets = []
    if @refs["saveBtn"]
      targets.push React.findDOMNode(@refs["saveBtn"])
    if @refs["removeBtn"]
      targets.push React.findDOMNode(@refs["removeBtn"])

    if event.relatedTarget in targets
      event.preventDefault()
      return
    else
      @_saveUrl()

  _saveUrl: =>
    if @state.urlInputValue.trim().length > 0
      @props.onSaveUrl @state.urlInputValue, @props.linkToModify
    @props.onDoneWithLink()

  _onInputChange: (event) =>
    @setState urlInputValue: event.target.value

  _detectEscape: (event) =>
    if event.key is "Escape"
      @props.onDoneWithLink()

  _saveUrlOnEnter: (event) =>
    if event.key is "Enter"
      if @state.urlInputValue.trim().length > 0
        @_saveUrl()
      else
        @_removeUrl()

  # We signify the removal of a url with an empty string. This protects us
  # from the case where people delete the url text and hit save. In that
  # case we also want to remove the link.
  _removeUrl: =>
    @setState urlInputValue: ""
    @props.onSaveUrl "", @props.linkToModify
    @props.onDoneWithLink()

  _initialUrl: (props=@props) =>
    initialUrl = props.linkToModify?.getAttribute('href')
    if not initialUrl
      if RegExpUtils.urlRegex().test(props.linkToModify?.textContent ? "")
        initialUrl = props.linkToModify.textContent

    return initialUrl


module.exports = LinkEditor
