quickconnect = require 'rtc-quickconnect'

window.quickconnect = quickconnect

voteActive = false

username = localStorage.username or prompt 'username'
room = localStorage.room or prompt 'Room name?'

localStorage.username = username
localStorage.room = room

sendVote = null
sendCall = null

peers = {}

VOTETIME = 10 # seconds

window.onload = ->

  document.querySelector('#callVote').addEventListener 'click', ->
    sendCall prompt("What's the story?")

  opts = {
    room: room
  }

  quickconnect("http://rtc.io/switchboard/", opts)
    .createDataChannel('votes')
    .on('channel:opened:votes', (id, dc) ->
      sendVote = (vote) ->
        dc.send JSON.stringify
          vote: vote
          username: username
      dc.onmessage = (evt) ->
        message = JSON.parse evt.data
        writeVote message.username, message.vote
    )
    .createDataChannel('calls')
    .on('channel:opened:calls', (id, dc) ->
      dc.onmessage = (evt) ->
        message = JSON.parse evt.data
        startVote message

      sendCall = (story) ->
        startVote  username: username, story: story

        dc.send JSON.stringify
          story: story
          username: username
    )
    .createDataChannel('peerInfo')
    .on 'channel:opened:peerInfo', (id, dc) ->
      dc.onmessage = (evt) ->
        message = JSON.parse evt.data
        peers[id] = username: message.username
        writePeers peers
      dc.send JSON.stringify
        username: username
    .on 'channel:closed:peerInfo', (id, dc) ->
      delete peers[id]
      writePeers peers

startVote = (message) ->
  return if voteActive

  setCurrentVote message.username, message.story

  writeCall message.story

  voteActive = true

  writeTimer VOTETIME

  intervalsElapsed = 0
  voteTicker = setInterval ->
    intervalsElapsed++

    writeTimer VOTETIME - intervalsElapsed

    if intervalsElapsed is VOTETIME
      clearInterval voteTicker

      chosenVote = getChosenVote()
      if chosenVote
        sendVote chosenVote
        writeVote username, chosenVote

      deselectAllVotes()

      voteActive = false

  , 1000

getChosenVote = ->
  node = document.querySelector('.voteOption[selected=true]')
  return node?.innerText

appendLine = (text, className) ->
  node = document.createElement 'P'
  node.className = className if className
  node.appendChild document.createTextNode text
  document.querySelector('#votes').appendChild node

writeVote = (name, vote) ->
  appendLine "#{name} says #{vote}"

writeCall = (story) ->
  appendLine "^ Votes for #{story}", 'contrast'

writeTimer = (num) ->
  document.querySelector('#timer').innerHTML = num

setCurrentVote = (username, story) ->
  document.querySelector('#voteName').innerHTML = "#{username} calls #{story}"

grabAllVotes = ->
  document.querySelectorAll('.voteOption')

deselectAllVotes = ->
  for elem in grabAllVotes()
    elem.setAttribute 'selected', false

selectThisVote = (elem) ->
  deselectAllVotes()
  elem.setAttribute 'selected', true

for elem in grabAllVotes()
  elem.addEventListener 'click', ->
    selectThisVote this

writePeers = (peers) ->
  htmlString = '<ul>'
  for _, data of peers
    htmlString += "<li>#{data.username}</li>"
  htmlString += '</ul>'
  document.querySelector('#peers').innerHTML = htmlString
