mesa = require '../src/mesa'

module.exports =

  'attached function is called with correct `this` value': (test) ->
    query = mesa.clone()
    query.attached = ->
      test.equal this, query
      test.done()

    query.attached()

  'beforeInsert callback is called with correct `this` value': (test) ->
    test.expect 1

    mockConnection =
      query: (sql, params, cb) ->
        cb null, {rows: []}
    query = mesa
      .table('user')
      .setConnection(mockConnection)
      .allowedColumns(['a'])
      .beforeInsert (data) ->
        test.equal this, query
        return data

    query.insert({a: 1}).then ->
      test.done()
