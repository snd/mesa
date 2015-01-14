mesa = require '../src/mesa'

module.exports =

  'user-added method is called with correct `this` value': (test) ->
    query = Object.create mesa
    query.attached = ->
      test.equal this, query
      test.done()

    query.attached()

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

  'queueBeforeEachInsert is called with correct default args and `this` value': (test) ->
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

  '.call(f) is called with correct default args and `this` value': (test) ->
    test.expect 2

    f = (x) ->
      test.equal this, mesa
      test.equal x, 'x'
      this

    mesa.call f, 'x'

    test.done()

  '.when(...) with false': (test) ->
    f = ->
      test.ok false
    mesa.when (1 is 2), f
    test.done()

  '.when(...) with true is called with correct default args and `this` value': (test) ->
    test.expect 3
    f = (arg1, arg2) ->
      test.equal this, mesa
      test.equal arg1, 1
      test.equal arg2, 2
      this
    mesa
      .when (2 is 2), f, 1, 2
    test.done()

  '.when(...) with true and .where()': (test) ->
    query = mesa
      .when true, mesa.where, 'a BETWEEN ? AND ?', 1, 10

    test.equal query.sql(), 'SELECT * WHERE a BETWEEN ? AND ?'
    test.deepEqual query.params(), [1, 10]

    test.done()

  # TODO test .each

  'getTable': (test) ->
    test.equal 'user', mesa.table('user').getTable()
    test.done()

  'the entire mohair interface works and is exposed': (test) ->
    # TODO
    test.done()
