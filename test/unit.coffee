mesa = require '../src/mesa'

module.exports =

  'attached function is called with correct `this` value': (test) ->
    query = mesa.clone()
    query.attached = ->
      test.equal this, query
      test.done()

    query.attached()

  'queueBeforeEachInsert is called with correct `this` value': (test) ->
    test.expect 1

    mockConnection =
      query: (sql, params, cb) ->
        cb null, {rows: []}
    query = mesa
      .table('user')
      .setConnection(mockConnection)
      .allow(['a'])
      .queueBeforeEachInsert (data) ->
        test.equal this, query
        return data

    query.insert({a: 1}).then ->
      test.done()

  '.call(f) is called with correct `this` value': (test) ->
    f = (x) ->
      test.equal this, mesa
      test.equal x, 'x'
      test.done()

    mesa.call f, 'x'

  'getTable': (test) ->
    # TODO
    # test.equal 'user', mesa.table('user').getTable()
    test.done()

  'complex mohair query with sql and params': (test) ->
    # TODO
    test.done()
