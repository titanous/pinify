$.domReady ->
  $('#uploadlink').click showUploadForm
  $('#fileinput').change uploadForm
  $('body').on 'dragenter', noop
  $('body').on 'dragover', noop
  $('body').on 'dragleave', noop
  $('body').on 'drop', uploadDrop

noop = (e) ->
  e.stopPropagation()
  e.preventDefault()

showUploadForm = (e) ->
  $('#fileinput').click()
  noop e

uploadForm = (e) ->
  upload e.target.files[0]

uploadDrop = (e) ->
  noop e
  upload e.dataTransfer.files[0]

upload = (file) ->
  $.upload
    url: '/upload'
    data: file
# FIXME:
    success: (data) -> window.location = "/#{data.id}"
    error: (error) -> console.log error
