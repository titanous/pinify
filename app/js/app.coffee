$.domReady ->
  $('#uploadlink').click showUploadForm
  $('#fileinput').change uploadForm
  $('body').on 'dragenter', noop
  $('body').on 'dragover', noop
  $('body').on 'dragleave', noop
  $('body').on 'drop', uploadDrop
  animatePage()

noop = (e) ->
  e.stopPropagation()
  e.preventDefault()

showUploadForm = (e) ->
  $('#fileinput').css(width: '100px', height: '20px').click()
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

pageTop = (v) ->
  page = $('#content')
  if v
    page.css('top', "#{v}px")
  else
    parseInt(page.css('top'))

animatePage = ->
  height = parseInt($('body').css('height'))
  pageTop(height-350) if pageTop() > height
  if pageTop() > 30
    pageTop(pageTop()-10)
    setTimeout(animatePage, 100)
