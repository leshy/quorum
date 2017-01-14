require! {
  liferaft
  colors
  util
  redis
  os
  leshdash: { each, tail, head, find, keys, defaultsDeep, map, wait }
  bluebird: p
  events: { EventEmitter }
}

# need to initialize logger before sails
# roles need to be able to suspend AND wake up, including master role

export class Client extends EventEmitter
  (opts) ->
    @ <<< defaultsDeep opts, do
      address: os.hostname! + "-" + process.pid

  getNodes: -> new p (resolve,reject) ~>
    resolve map @raft.nodes, (.address)
  
  message: (node, msg) -> new p (resolve,reject) ~> 
    @raft.message node, @raft.packet('quorummsg', msg), (err, data) ->
      if err then return reject err
      resolve data
  
  connect: (host="localhost") ->
    @queries = {}
    
    @pub = redis.createClient host: host
    @sub = redis.createClient host: host
    
    @sub.psubscribe "raft:#{@address}:*"
    directory = redis.createClient host: host
    directory.subscribe "raftdirectory"

    p.props do
      sub: (~> new p (resolve,reject) ~> @sub.once "psubscribe", ~> resolve @sub)()
      pub: (~> new p (resolve,reject) ~> @pub.once "connect", ~> resolve @pub)()
      directory: (~> new p (resolve,reject) ~> directory.once "subscribe", ~> resolve directory)()

    .then (pubSub) ~> new p (resolve,reject) ~>
      publishSelf = ~> @pub.publish "raftdirectory", "add:" + @address
      publishSelf!
      
      @raft = new Raft pubSub <<< do
        address: @address
        'heartbeat timeout': '1000 millisecond',
        'heartbeat': '1000 millisecond',
        'election min': '1500 millisecond',
        'election max': '2 second'

      nodes = {}
                  
      directory.on "message", (channel,msg) ~>
        [action, address] = msg.split(':')
        
        switch action
        
          | "add" =>
            if not nodes[address]?
              nodes[address] = true
              @raft.join address
              publishSelf!
              @emit "addNode", address

          | "rem" =>
            @emit "delNode", @address
            @raft.leave address
        
      directory.once "message", -> resolve!

      @raft.on 'rpc', (packet, reply) ~>
        if packet.type == 'ping' then return reply pong: true
        if packet.type == 'quorummsg' then @emit 'msg', packet.data, reply

      @raft.once 'leader', ~> 
        setInterval do
          ~>
            packet = @raft.packet 'ping', { ping: true }
            @raft.message liferaft.FOLLOWER, packet, (err,data) ~> 
              if err then each err, (val, address) ~>
                @pub.publish "raftdirectory", "rem:" + address
          1000
                                                
Raft = liferaft.extend do
  initialize: ({ pub, sub, address }: opts, callback) ->
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
        id = String new Date().getTime() + Math.random()
        @self.queries[id] = reply
        setTimeout (~>
          
          if cb = @self.queries[id]
            delete @self.queries[id]
            cb new Error "timeout"
          ), @beat
        address += ":query:#{id}"
        
      | String =>
        address += ":reply:#{reply}"

#    console.log "#{address} >>>", @address, packet
    @self.pub.publish address, JSON.stringify packet
