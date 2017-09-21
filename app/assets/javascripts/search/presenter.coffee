# Frontend Search Implementation - Presenter
# The presenter handles communication between the view and the model.
# It's like a rails Controller, but also handles requests from the view (JS
# callbacks)
# Patterns: Single Instance; Model-Template-Presenter-ViewModel structure
class Clarat.Search.Presenter extends ActiveScript.Presenter
  # This SubApplication sits inside the RoR Offers#index
  constructor: ->
    super()

    @model = Clarat.Search.Model.load()
    @searchFramework()


  ### "CREATE ACTION" ###

  ###
  Sending a search means that we compile the available parameters into
  a search query and instead of sending (saving) it to our database, we send
  it to a remote search index, which returns aus the completed search objects
  for the onMainResults view. That means #onMainResults can't be called directly
  without #sendMainSearch as it's not persisted.
  ###
  sendMainSearch: =>
    @model.getMainSearchResults().then(@onMainResults).catch(@failure)

  sendLocationSupportSearch: =>
    @model.getLocationSupportResults().then(@onLocationSupportResults).catch(
      @failure
    )

  sendQuerySupportSearch: =>
    @model.getQuerySupportResults().then(@onQuerySupportResults).catch(
      @failure
    )


  ### "SHOW ACTIONS" ###

  # Renders a mostly empty wireframe that the search results will be placed in.
  searchFramework: ->
    @render '#search-wrapper', 'search', new Clarat.Search.Cell.Search(@model)
    Clarat.Search.Operation.UpdateAdvancedSearch.run @model
    $(document).trigger 'Clarat.Search::FirstSearchRendered'

  # Rendered upon successful sendMainSearch.
  onMainResults: (resultSet) =>
    viewModel = new Clarat.Search.Cell.SearchResults resultSet, @model

    @render '.Listing-results', 'search_results', viewModel
    if resultSet.results[0].nbHits < 1
      @hideMapUnderCategories()
    else if @model.isPersonal()
      @showMapUnderCategories()
      if $(window).width() < 750
        @showPersonalControls()
      Clarat.Search.Operation.BuildMap.run viewModel.main_offers
    $(document).trigger 'Clarat.Search::NewResults', resultSet

  # Support Results only change when location changes. TODO: facets?
  onLocationSupportResults: (resultSet) =>
    nearbyResults = resultSet.results[0]
    remoteFacetResults = resultSet.results[1]
    personalFacetResults = resultSet.results[2]

    if nearbyResults.nbHits < 1
      Clarat.Modal.open('#unavailable_location_overlay')
      @handleChangeToRemote()

    $(document).trigger 'Clarat.Search::NewLocationSupportResults', [
      remoteFacetResults,
      personalFacetResults
    ]


  onQuerySupportResults: (resultSet) =>
    remoteFacetResults = resultSet.results[0]
    personalFacetResults = resultSet.results[1]
    $(document).trigger 'Clarat.Search::NewQuerySupportResults', [
      remoteFacetResults,
      personalFacetResults
    ]


  ### CALLBACKS ###

  CALLBACKS:
    document:
      'Clarat.Location::NewLocation': 'handleNewGeolocation'
      'Clarat.Search::URLupdated': 'handleURLupdated'
    window:
      popstate: 'handlePopstate'
    '#search_form_query':
      keyup: 'handleQueryKeyUp'
      change: 'handleQueryChange'
    '.JS-RemoveQueryLink':
      click: 'handleRemoveQueryClick'
    '.JS-MoreInformationButton':
      click: 'handleShowMoreInformaiton'
    '.more-information-text':
      click: 'handleShowMoreInformaiton'
    '.JS-RemoveExactLocationClick':
      click: 'handleRemoveExactLocationClick'
    '.JS-SwitchToRemote':
      click: 'handleClickToRemote'
    '.JS-SwitchToPersonal':
      click: 'handleClickToPersonal'
    '.JS-PaginationLink':
      click: 'handlePaginationClick'

    '.JS-SortOrderSelector':
      change: 'handleSortOrderChange'
    '#advanced_search .JS-TargetAudienceSelector':
      change: 'handleFilterChange'
    '#advanced_search .JS-ExclusiveGenderSelector':
      change: 'handleFilterChange'
    '#advanced_search .JS-LanguageSelector':
      change: 'handleFilterChange'
    '#advanced_search .JS-ResidencyStatusSelector':
      change: 'handleFilterChange'

    ## Radio state handling contact_type
    # 'input[name=contact_type][value=remote]:checked':
    #   change: 'handleChangeToRemote'
    # 'input[name=contact_type][value=personal]:checked':
    #   change: 'handleChangeToPersonal'
    #   'Clarat.Search::InitialDisable': 'disableCheckboxes'

  handleQueryKeyUp: (event) =>
    @model.assignAttributes query: event.target.value
    @sendMainSearch()
    @sendQuerySupportSearch()

  # We don't want to update all the time when user is typing. Persistence only
  # happens when they are done (and this fires). No need to send new search.
  handleQueryChange: (event) =>
    @model.updateAttributes query: event.target.value
    @sendQuerySupportSearch()

  handleNewGeolocation: (event, location) =>
    @model.updateAttributes
      search_location: location.query || ''
      generated_geolocation: location.geoloc || ''
      exact_location: false
    @sendMainSearch()
    @sendLocationSupportSearch() # only needs to be called on new location

  handleRemoveQueryClick: (event) =>
    @model.updateAttributes query: ''
    @sendMainSearch()
    @sendQuerySupportSearch()

  handleShowMoreInformaiton: (event) =>
    Clarat.Modal.open('#more_information_overlay')

  handleRemoveExactLocationClick: (event) =>
    if @model.exact_location == 'true'
      @model.updateAttributes
        exact_location: false
        search_location: 'Berlin'
      @sendMainSearch()
      @sendQuerySupportSearch()

  handlePaginationClick: (event) =>
    changes =
      page: @getNestedData(event.target, '.JS-PaginationLink', 'page') - 1
    @model.assignAttributes changes
    @model.save changes, true
    @sendMainSearch()
    @stopEvent event
    window.scrollTo(0, 0)

  handleFilterChange: (event) =>
    val = $(event.target).val()
    val = if val is 'any' then '' else val
    field = $(event.target).attr('name') or $(event.target).parent.attr('name')

    @model.updateAttributes "#{field}": val
    @sendMainSearch()
    @sendQuerySupportSearch()

  handleSortOrderChange: (event) =>
    requestedSortOrder = $(event.target).val()
    @model.updateAttributes sort_order: requestedSortOrder
    @sendMainSearch()
    Clarat.Search.Operation.UpdateAdvancedSearch.run @model

  handleEncounterChange: (event) =>
    if @model.isPersonal() == false
      return @handleChangeToPersonal()

    # explicitly reset the page variable
    @model.resetPageVariable()
    @sendMainSearch()
    @sendQuerySupportSearch()

  handleClickToPersonal: (event) =>
    @stopEvent event
    @handleChangeToPersonal()

  # disable and check all remote checkboxes, model has every encounter again
  handleChangeToPersonal: =>
    @model.contact_type = 'personal'
    @showMapUnderCategories()
    @showPersonalControls()

    # explicitly reset the page variable
    @model.resetPageVariable()
    @model.save contact_type: 'personal'
    @sendMainSearch()
    @sendQuerySupportSearch()

  handleClickToRemote: (event) =>
    @stopEvent event
    @handleChangeToRemote()

  handleChangeToRemote: =>
    @model.updateAttributes contact_type: 'remote'
    @hideMapUnderCategories()
    @hidePersonalControls()
    $('#contact_type_remote').prop('checked', true)

    $('.filter-form__checkboxes-wrapper input').each ->
      $(this).attr 'disabled', false

    @sendMainSearch()
    @sendQuerySupportSearch()

  handleURLupdated: =>
    # Fix for Safari & old Chrome: prevent initial popstate from affecting us.
    @popstateEnabled = true
  handlePopstate: =>
    return unless @popstateEnabled
    window.location = window.location
    # TODO: for more performance we could load from the event.state instead of
    #       reloading

  ### Non-event-handling private methods ###

  hideMapUnderCategories: =>
    $('.aside-standard__container').hide()

  showMapUnderCategories: =>
    $('.aside-standard__container').show()

  hidePersonalControls: =>
    $('#advanced_search .sort_order').hide()
    $("#tab2").hide()
    $('.off-canvas-container__trigger[data-target="#tab2"]').parent().hide()

  showPersonalControls: =>
    $("#tab2").css("display", "inline-block")
    $('.off-canvas-container__trigger[data-target="#tab2"]').parent().show()

  getNestedData: (eventTarget, selector, elementName) ->
    $(eventTarget).data(elementName) or
      $(eventTarget).parents(selector).data(elementName) or ''

  # Error view, rendered in case of any sendMainSearch/onMainResults exceptions.
  failure: (error) =>
    console.log error
    console.trace()
    @render '#search-wrapper', 'error_ajax', I18n.t('js.ajax_error')
