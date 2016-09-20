require! {
  liferaft
  colors
  util
  redis
  os
  lodash: { each, tail, head, find, keys, defaultsDeep }
  bluebird: p
}

export class Client
  (opts) ->
    @ <<< defaultsDeep opts, do
      address: os.hostname! + "_" + process.pid

  connect: ->
    @queries = {}

    @pub = redis.createClient!

    @sub = redis.createClient!
    @sub.psubscribe "raft:#{@address}:*"
    
    seed = redis.createClient!
    seed.subscribe "raftseed"

    p.props do
      sub: (~> new p (resolve,reject) ~> @sub.once "psubscribe", ~> resolve @sub)()
      pub: (~> new p (resolve,reject) ~> @pub.once "connect", ~> resolve @pub)()
      seed: (~> new p (resolve,reject) ~> seed.once "subscribe", ~> resolve seed)()

    .then (pubSub) ~> new p (resolve,reject) ~> 
      @pub.publish "raftseed", @address
      @raft = new Raft pubSub <<< address: @address
      
      console.log 'wait on seed'
      seed.on "message", (channel,address) ~>
        @raft.join address
        
      seed.once "message", -> resolve!
      
      
Raft = liferaft.extend do
  initialize: ({ pub, sub, address, parent }: opts, callback) ->
    @queries = {}
    @pub = pub
    
    callback()
    
    sub.on "pmessage", (pattern, channel, message) ~>
      packet = JSON.parse message
      channel = channel.split ":"
      
      if channel.length is 4
        qtype = channel[2]
        id = channel[3]

        if qtype is "reply" then
          if cb = @queries[id]
            delete @queries[id]
            cb void, packet

        if qtype is "query" then 
          reply = (message) ~> @writeTo packet.address, message, id
        
      @emit 'data', packet, reply

  writeTo: (address, packet, reply) ->
    node = find @nodes, -> it.address is address
    if not node then node = @join address
    node.write packet, reply

  # either receive reply F for a reply
  # or String, that means this is the answer
  write: (packet, reply) ->
    address = "raft:#{@address}"

    switch reply?@@
      | Function =>
        id = String new Date().getTime()
        @parent.queries[id] = reply
        setTimeout (~>  delete @parent.queries[id]), @beat

        address += ":query:#{id}"
        
      | String =>
        address += ":reply:#{reply}"

#    console.log "#{address} >>>", @address, packet
    @parent.pub.publish address, JSON.stringify packet

# raft = new Raft address
# #  'election min': 2000
# #  'election max': 5000
# #  'heartbeat': 1000


# #setInterval do
# #  -> console.log raft.log
# #  1000
  
# debug = require('diagnostics')('raft')
  
# raft.on "error", -> console.log "ERROR", it
# #raft.on "heartbeat", -> console.log "hb"

# raft.on 'heartbeat timeout', -> 
#   debug('heart beat timeout, starting election');

# raft
#   .on 'term change', (to, from) -> 
#     debug('were now running on term %s -- was %s ', to, from)
    
#   .on 'leader change', (to, from) -> 
#     debug('we have a new leader to: %s -- was %s', to, from);
    
#   .on 'state change', (to, from) -> 
#     debug('we have a new state to: %s -- was %s', to, from);

# raft.on 'leader', -> 
#   console.log(colors.red 'I am elected as leader');

# raft.on 'candidate', -> 
#   console.log(colors.green 'I am starting as candidate');

# raft.on 'follower', -> 
#   console.log(colors.magenta 'I am starting as follower');

# nodes = <[ test1 test2 test3 test4 test5 test6 ]>
# each nodes, -> if address isnt it then raft.join it
