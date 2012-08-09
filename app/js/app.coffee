scrolling = false
loading = false

# Track all the timings
_gaq.push ['_setSiteSpeedSampleRate', 100]

class Timing
  constructor: (@category, @variable) ->
    @start = new Date().getTime()

  send: ->
    @end = new Date().getTime()
    @duration = @end - @start
    _gaq.push ['_trackTiming', @category, @variable, @duration]


$.domReady ->
  $('body').on('dragenter', noop).on('dragover', noop).on('dragleave', noop).on('drop', uploadDrop)
  $(window).on('resize', debounce(updatePageHeight, 100)).on('popstate', scrollback)
  $('#file-upload').click showUploadForm
  $('#file-input').change uploadForm
  $('#animate').on 'click', (e) -> noop(e); scrollToEnd(undefined, true) unless scrolling
  addImgurHandler()
  scrollToEnd()
  mixpanel.track_links('.image a', 'Image click', (e) -> id: imageId(e))
  mixpanel.track_links('.imgur-link', 'Imgur click', (e) -> id: imageId(e))
  mixpanel.track_links('.tweet a', 'Tweet click', (e) -> id: imageId(e))

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
  upload e.dataTransfer.files[0] if e.dataTransfer.files.length > 0

upload = (file) ->
  startLoading()
  timing = new Timing('Response Time', 'Pinify')
  $.upload
    url: '/upload'
    data: file
    success: (data) ->
      stopLoading()
      timing.send()
      trackEvent('Pinify', data.id, timing.duration)
      history.pushState({ id: data.id }, '', data.id)
      mixpanel.track_pageview('/'+data.id)
      printContent(data.content)
      addImgurHandler()
    error: (error) ->
      stopLoading()
      printContent "<div>Something went wrong. Try again with a different image and make sure it is smaller than 4MB.</div>"

printContent = (html) ->
  $('#page').append(html)
  scrollToEnd() unless scrolling

pageTop = (v) ->
  page = $('#content')
  if v
    page.css('top', "#{v}px")
  else
    parseInt(page.css('top'))

pageHeight = -> $('#page').height()

scrollToEnd = (lastPageHeight, reanimate) ->
  height = $('body').height()
  pageTop(height-350) if reanimate or pageTop() > height
  if (!lastPageHeight? and !reanimate) or lastPageHeight < pageHeight() or $('#content').height() < pageHeight()+350
    scrolling = true
    pageTop(pageTop()-10)
    setTimeout (-> scrollToEnd(pageHeight())), 75
  else
    scrolling = false

scrollTo = (target) ->
  if Math.floor(pageTop()/10) != Math.floor(target/10)
    scrolling = true
    if pageTop() > target
      pageTop(pageTop()-10)
    else
      pageTop(pageTop()+10)
    setTimeout (-> scrollTo(target)), 40
  else
    scrolling = false

updatePageHeight = ->
  return if scrolling
  top = $('body').height() - pageHeight() - 350
  pageTop top

scrollback = (e) ->
  return unless $('.xhr').length > 0 # return unless an image has been uploaded
  if id = e.originalEvent.state?.id
    el = $('#'+id)
    offset = el.offset().top - 50
    offset += 200 if el.hasClass('xhr')
    scrollTo pageTop() - offset
  else
    scrollTo 100

pageUrl = ->
  l = window.location
  "#{l.protocol}//#{l.host}#{l.pathname}"

uploadToImgur = (e) ->
  noop(e) if e
  startLoading()
  timing = new Timing('Response Time', 'Imgur upload')
  $.ajax
    url: 'http://api.imgur.com/2/upload.json'
    method: 'post'
    type: 'json'
    crossOrigin: true
    data: { key: 'f6d3ba052d7c914c91294dbe44860dfd', type: 'url', image: $(e.target).data('src') }
    success: (data) ->
      stopLoading()
      timing.send()
      redirect = -> window.location.href = "#{pageUrl()}/imgur?hash=#{data.upload.image.hash}"
      trackEvent('Imgur upload', imageId(e.target), timing.duration, redirect)
      setTimeout(redirect, 300)
    error: ->
      stopLoading()
      printContent "<div>Something went wrong, try again later.</div>"

trackEvent = (action, id, timing, callback) ->
  _gaq.push ['_trackEvent', 'Actions', action, id, timing]
  mixpanel.track(action, { id: id, timing: timing }, callback)

startLoading = ->
  printContent "<div class='loading'>Uploading.......</div>"
  loading = setTimeout startLoading, 1500

stopLoading = ->
  clearTimeout(loading)
  loading = false

addImgurHandler = -> $('.imgur-upload').on 'click', uploadToImgur

imageId = (el) ->
  $(el).closest('.image-wrapper').attr('id')


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
