mesa = require '../src/mesa'

module.exports =

  'attached function is called with correct `this` value': (test) ->
    query = Object.create mesa
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

  'queueBeforeEachInsert with default args is called with correct `this` value': (test) ->
    test.expect 3

    mockConnection =
      query: (sql, params, cb) ->
        cb null, {rows: []}
    query = mesa
      .table('user')
      .setConnection(mockConnection)
      .allow(['a'])
      .queueBeforeEachInsert ((data, arg2, arg3) ->
          test.equal this, query
          test.equal arg2, 'arg2'
          test.equal arg3, 'arg3'
          return data
      ), 'arg2', 'arg3'

    query.insert({a: 1}).then ->
      test.done()

  '.call(f) is called with correct `this` value': (test) ->
    f = (x) ->
      test.equal this, mesa
      test.equal x, 'x'
      test.done()

    mesa.call f, 'x'

  'user-added method is copied and can be chained': (test) ->
    table = mesa.table('user')
    thisInFoo = null
    table.foo = ->
      thisInFoo = this
      this
    rightBeforeCallToFoo = table
      .allow('a', 'b')
      .where(c: 3)

    rightBeforeCallToFoo
      .foo()
      .order('id DESC')

    test.equal rightBeforeCallToFoo, thisInFoo

    test.done()

  'getTable': (test) ->
    # TODO
    # test.equal 'user', mesa.table('user').getTable()
    test.done()

  'complex mohair query with sql and params': (test) ->
    # TODO
    test.done()
