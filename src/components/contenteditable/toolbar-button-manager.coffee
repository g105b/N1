{ContenteditableExtension} = require 'nylas-exports'
ToolbarButtons = require './toolbar-buttons'

# This contains the logic to declaratively render the core
# <ToolbarButtons> component in a <FloatingToolbar>
class ToolbarButtonManager extends ContenteditableExtension

  # See the {EmphasisFormatting} and {LinkManager} and other extensions
  # for toolbarButtons.
  @toolbarButtons: ({toolbarState}) => []

  @toolbarComponentData: ({toolbarState, bindToEditor}) =>
    return null if toolbarState.dragging or toolbarState.doubleDown
    return null if toolbarState.exportedSelection.isCollapsed

    return {
      component: ToolbarButtons
      props: toolbarState.extensions
      locationRef: DOMUtils.getRangeInScope(toolbarState.editableNode)
      width: @_numButtons(toolbarState) * 28.5
    }

    return {component, props, locationRef, width}

  @_numButtons: (toolbarState) ->
    extensions.map((ext) ->
      (ext.toolbarButtons?(toolbarState) ? []).length
    ).reduce((a,n) -> a+n)

module.exports = ToolbarButtonManager
