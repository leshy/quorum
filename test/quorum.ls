


transport = new quorum-transport-smokesignal()

transport.addSeed "bla"


quorum = new Quorum do
  seed:
    redis:
      host: "localhost"

  transport: "smokesignal"

quorum.addProtocol new protocols.Raft()

quorum.raft.master().then (master) ->
  master.query bla: 3, (reply) ->
    true

    
quorum.query ( getRole: true )
