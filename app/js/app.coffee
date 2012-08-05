$.domReady ->
  $('#uploadlink').click showUploadForm
  $('#fileinput').change uploadForm
  $('body').on 'dragenter', noop
  $('body').on 'dragover', noop
  $('body').on 'dragleave', noop
  $('body').on 'drop', uploadDrop
  $('#animate').on 'click', (e) -> noop(e); animatePage(true)
  $('#upload').on 'click', uploadToImgur
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

animatePage = (reanimate) ->
  height = parseInt($('body').css('height'))
  pageTop(height-350) if reanimate or pageTop() > height
  if pageTop() > 30
    pageTop(pageTop()-10)
    setTimeout(animatePage, 100)

pageUrl = ->
  l = window.location
  "#{l.protocol}//#{l.host}#{l.pathname}"

uploadToImgur = (e) ->
  noop(e) if e
  $.ajax
    url: 'http://api.imgur.com/2/upload.json'
    method: 'post'
    type: 'json'
    crossOrigin: true
    data: { key: 'f6d3ba052d7c914c91294dbe44860dfd', type: 'url', image: imageUrl }
    success: (data) ->
      window.location.href = "#{pageUrl()}/imgur?hash=#{data.upload.image.hash}"
