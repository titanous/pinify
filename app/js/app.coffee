animating = false
loading = false

$.domReady ->
  $('body').on('dragenter', noop).on('dragover', noop).on('dragleave', noop).on('drop', uploadDrop)
  $(window).on 'resize', debounce(updatePageHeight, 100)
  $('#file-upload').click showUploadForm
  $('#file-input').change uploadForm
  $('#animate').on 'click', (e) -> noop(e); animatePage(undefined, true) unless animating
  $('#imgur-upload').on 'click', uploadToImgur
  animatePage()

noop = (e) ->
  e.stopPropagation()
  e.preventDefault()

showUploadForm = (e) ->
  noop e
  input = $('#file-input')
  # Input form must be visible for click() to work in Firefox
  input.css(width: '100px', height: '20px') if navigator.userAgent.indexOf('Firefox') != -1
  input.click()

uploadForm = (e) ->
  upload e.target.files[0]

uploadDrop = (e) ->
  noop e
  upload e.dataTransfer.files[0]

upload = (file) ->
  startLoading()
  $.upload
    url: '/upload'
    data: file
    success: (data) ->
      stopLoading()
      history.pushState({}, '', data.id)
      $('#page').addClass('uploaded')
      printContent(data.content)
    error: (error) ->
      stopLoading()
      console.log error

printContent = (html) ->
  $('#page').append(html)
  animatePage() unless animating

pageTop = (v) ->
  page = $('#content')
  if v
    page.css('top', "#{v}px")
  else
    parseInt(page.css('top'))

pageHeight = -> $('#page').height()

animatePage = (lastPageHeight, reanimate) ->
  height = $('body').height()
  pageTop(height-350) if reanimate or pageTop() > height
  if (!lastPageHeight? and !reanimate) or lastPageHeight < pageHeight() or $('#content').height() < pageHeight()+350
    animating = true
    pageTop(pageTop()-10)
    setTimeout (-> animatePage(pageHeight())), 100
  else
    animating = false

updatePageHeight = ->
  return if animating
  top = $('body').height() - pageHeight() - 350
  console.log(top)
  pageTop top

pageUrl = ->
  l = window.location
  "#{l.protocol}//#{l.host}#{l.pathname}"

uploadToImgur = (e) ->
  noop(e) if e
  startLoading()
  $.ajax
    url: 'http://api.imgur.com/2/upload.json'
    method: 'post'
    type: 'json'
    crossOrigin: true
    data: { key: 'f6d3ba052d7c914c91294dbe44860dfd', type: 'url', image: $('#imgur-upload').data('src') }
    success: (data) ->
      window.location.href = "#{pageUrl()}/imgur?hash=#{data.upload.image.hash}"

startLoading = ->
  printContent "<div class='loading'>Uploading.......</div>"
  loading = setTimeout startLoading, 1500

stopLoading = ->
  clearTimeout(loading)
  loading = false

# From https://github.com/clux/wrappers
debounce = (fn, wait, leading) ->
  timeout = undefined
  ->
    context = this
    args = arguments
    fn.apply context, args if leading and not timeout
    clearTimeout timeout
    timeout = setTimeout(->
      timeout = null
      fn.apply context, args unless leading
    , wait)
