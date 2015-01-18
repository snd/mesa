mesa = require '../src/mesa'

module.exports =

  'first() with ignored argument': (test) ->
    try
      mesa.first(1)
    catch e
      test.equal e.message, 'you called .first() with an argument but .first() ignores all arguments. .first() returns a promise and maybe you wanted to call that promise instead: .first().then(function(result) { ... })'
      test.done()

  'insert with no allowed columns': (test) ->
    mesa.table('user').insert({a: 1}).catch (e) ->
      test.equal e.message, 'no columns are allowed. this will make .update() or .insert() fail. call .allow(columns...) with at least one column before .insert() or .update(). alternatively call .unsafe() before to disable mass assignment protection altogether.'
      test.done()

  'update with no allowed columns': (test) ->
    mesa.table('user').update({a: 1}).catch (e) ->
      test.equal e.message, 'no columns are allowed. this will make .update() or .insert() fail. call .allow(columns...) with at least one column before .insert() or .update(). alternatively call .unsafe() before to disable mass assignment protection altogether.'
      test.done()

  'setConnection without function or object argument': (test) ->
    try
      mesa.setConnection(1)
    catch e
      test.equal e.message, '.setConnection() must be called with either a connection object or a function that takes a callback and calls it with a connection'
      test.done()

  'query with sql fragment and params': (test) ->
    fragment =
      sql: -> 'SELECT * FROM "user" WHERE name = $1'
      params: -> ['laura']
    try
      mesa.query(fragment, [])
    catch e
      test.equal e.message, 'query with sql fragment as first arg is not allowed to have a second arg'
      test.done()

  'find without preceeding .setConnection()': (test) ->
    mesa.find().catch (e) ->
      test.equal e.message, 'the method you are calling requires a call to .setConnection() before it'
      test.done()

  'insert without preceeding .setConnection()': (test) ->
    mesa.table('user').unsafe().insert({a: 1}).catch (e) ->
      test.equal e.message, 'the method you are calling requires a call to .setConnection() before it'
      test.done()

  'no records to insert': (test) ->
    try
      mesa.table('user').insert()
    catch e
      test.equal e.message, 'no records to insert'
      test.done()

  'empty record after queue': (test) ->
    try
      mesa.table('user')
        # .debug (args...) -> console.log args[...3]...
        .unsafe()
        .queueBeforeEach((record) ->
          delete record.b
          record
        )
        .insert {a: 1}, {b: 2}, {c: 3}
        .catch (e) ->
          test.equal e.message, 'insert would fail because record at index 1 is empty after processing before queue'
          test.done()
