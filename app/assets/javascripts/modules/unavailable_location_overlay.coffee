# using http://vast-engineering.github.io/jquery-popup-overlay/
$(document).ready ->
  overlay = $('#unavailable_location_overlay')
  if overlay.length
    overlay.popup
      autoopen: true
