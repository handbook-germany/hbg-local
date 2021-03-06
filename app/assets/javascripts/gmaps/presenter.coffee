# Google Maps Display - Presenter
class Clarat.GMaps.Presenter extends ActiveScript.Presenter
  # canvas - the DOM element that functions as the map canvas
  # data - the DOM element that provides additional information for the map:
  #   markers - a list of markers that are to be set in the map
  #   options - map API options that will be transmitted to Google
  #   ui - user interface options for internal use (like autoenlarge)
  constructor: (@markers) ->
    super()
    @canvas = document.getElementById('map-canvas')
    @data = $('#map-data')
    @markers = @data.data('markers') unless @markers
    @mapOptions = @data.data('options') or {}
    @uiOptions = @data.data('ui') or {}
    return unless @markers

    # For Issue #783
    $('body').addClass 'has-google-map'

    @currentMap = Clarat.GMaps.Operation.ConstructMap.run(
      @markers, @canvas, @mapOptions, @uiOptions)
    @handleMapResize()

    @mapModal = new Clarat.MapModal.Presenter # handles Map Button

  CALLBACKS:
    '#map-container':
      mousedown: 'handleMapClick'
      'Clarat.GMaps::MarkerMouseOver': 'handleMarkerMouseOver'
      'Clarat.GMaps::MarkerMouseOut': 'handleMarkerMouseOut'
      'Clarat.GMaps::MapClick': 'handleNativeMapClick'
      'Clarat.GMaps::Resize': 'handleMapResize'
      'Clarat.MapModal::Close': 'handleClosingModal'
    '.JS-trigger-marker':
      mouseover: 'handleResultMouseOver'
      mouseout: 'handleResultMouseOut'

  # Expand map to include all currently contained markers
  handleMapResize: =>
    google.maps.event.trigger @currentMap.instance, 'resize'

    # For more than one marker, resize to fit all of them
    if @currentMap.includedPoints.length > 1
      @currentMap.instance.fitBounds @currentMap.bounds

    # For a single marker, center on that one and zoom out
    else
      @currentMap.instance.setCenter(
        @currentMap.bounds.getCenter()
      )
      @currentMap.instance.setZoom 15

  handleMarkerMouseOver: (_event, marker, markerData) =>
    for id in markerData.ids
      $("#result-offer-#{id} .Listing-results__offer")
        .addClass('Listing-results__offer--highlighted')
    @_switchMarkerImage(marker, 'gmaps_marker_highlighted')

  handleMarkerMouseOut: (_event, marker, markerData) =>
    for id in markerData.ids
      $("#result-offer-#{id} .Listing-results__offer")
        .removeClass('Listing-results__offer--highlighted')
    @_switchMarkerImage(marker, 'gmaps_marker_1')

  handleResultMouseOver: (event) =>
    marker = $(event.currentTarget).data('marker')
    @_switchMarkerImage(marker, 'gmaps_marker_highlighted') if marker

  handleResultMouseOut: (event) =>
    marker = $(event.currentTarget).data('marker')
    @_switchMarkerImage(marker, 'gmaps_marker_1') if marker

  # called by library internally; listener set in Operations.ConstructMap
  handleNativeMapClick: (e) =>
    @infowindow.close()

  handleMapClick: (e) =>
    if @uiOptions['autoenlarge'] and @uiOptions['autoenlarge'] is true
      @mapModal.modal.popup('show')
      @currentMap.instance.setOptions({ draggableCursor: null })

  handleClosingModal: (e) =>
    if @uiOptions['autoenlarge'] and @uiOptions['autoenlarge'] is true
      @currentMap.instance.setOptions({ draggableCursor: 'pointer' })

  ### PRIVATE (ue) ###

  _switchMarkerImage: (marker, state) ->
    marker.setIcon(
      Clarat.GMaps.Operation.ConstructMap.markerUrl(state)
    )
