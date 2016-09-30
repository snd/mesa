{setup, teardown, mesa, spy} = require './src/common'

module.exports =

  'setUp': setup
  'tearDown': teardown

  'getConnection': (test) ->
    debug = spy()
    mesa
      .debug(debug)
      .getConnection()
      .then ({connection, done}) ->
        test.ok connection?
        test.equals debug.calls.length, 1
        done()
        test.equals debug.calls.length, 2
        test.done()

  'getConnection - error': (test) ->
    mesa
      .setConnection (cb) -> cb new Error 'expected connection error'
      .getConnection()
      .catch (err) ->
        test.equals err.message, 'expected connection error'
        test.done()

  'wrapInTransaction - commit': (test) ->
    test.expect 3
    debug = spy()
    mesa
      .debug(debug)
      .wrapInTransaction(
        (transaction) ->
          withTransaction = mesa.setConnection transaction
          withTransaction
            .query('INSERT INTO "user"(name) VALUES ($1)', ['josie'])
            .then ->
              withTransaction.query('SELECT * FROM "user"')
            .then (results) ->
              test.equal results.rows.length, 7
      ).then ->
        mesa.query('SELECT * FROM "user"').then (results) ->
          test.equal results.rows.length, 7
          test.equal debug.calls.length, 10
          test.done()

  'wrapInTransaction - rollback': (test) ->
    test.expect 3
    debug = spy()
    mesa
      .debug(debug)
      .wrapInTransaction(
        (transaction) ->
          withTransaction = mesa.setConnection transaction
          withTransaction
            .query('INSERT INTO "user"(name) VALUES ($1)', ['josie'])
            .then ->
              withTransaction.query('SELECT * FROM "user"')
            .then (results) ->
              test.equal results.rows.length, 7
              throw new Error 'rollback please'
      ).catch ->
        mesa.query('SELECT * FROM "user"').then (results) ->
          test.equal results.rows.length, 6
          test.equal debug.calls.length, 10
        test.done()
