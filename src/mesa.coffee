mohair = require 'mohair'
Promise = require 'bluebird'

###################################################################################
# helpers

helpers = {}

# escape that handles table schemas correctly:
# schemaAwareEscape('someschema.users') -> '"someschema"."users"
helpers.schemaAwareEscape = (string) ->
  string.split(".").map((str) -> "\"#{str}\"").join '.'

helpers.defaultMohair = mohair
  .escape(helpers.schemaAwareEscape)
  # return everything by default
  .returning('*')

# async: hooks can return promises !
helpers.runPipeline = (context, pipeline, record) ->
  reducer = (soFar, step) ->
    soFar.then step.bind(context)
  pipeline.reduce reducer, Promise.resolve record

helpers.afterQuery = (context, returnFirst, pipeline, queryResults) ->
  if queryResults.rows?
    processRow = (row) ->
      helpers.runPipeline context, pipeline, row
    Promise.all(queryResults.rows.map processRow).then (processedRows) ->
      if returnFirst
        processedRows[0]
      else
        processedRows
  else
    results

# TODO better name
helpers.replacePlaceholders = (sql) ->
  # replace ?, ?, ... with $1, $2, ...
  index = 1
  sql.replace /\?/g, -> '$' + index++

helpers.pick = (record, keys) ->
  picked = {}
  keys.forEach (column) ->
    if (column of record)
      picked[column] = record[column]
  return picked

helpers.pgDestroyPool = (pg, config) ->
  poolKey = JSON.stringify(config)
  console.log 'pgDestroyPool'
  console.log 'Object.keys(pg.pools.all)', Object.keys(pg.pools.all)
  console.log 'poolKey', poolKey
  pool = pg.pools.all[poolKey]
  console.log 'pool?', pool?
  if pool?
    new Promise (resolve, reject) ->
      pool.drain ->
        # https://github.com/coopernurse/node-pool#step-3---drain-pool-during-shutdown-optional
        pool.destroyAllNow ->
          delete pg.pools.all[poolKey]
          resolve()
  else
    Promise.resolve()

###################################################################################
# core

module.exports =

  clone: ->
    Object.create @

  # the magic behind mohair's fluent interface:
  # prototypically inherit from `this` and set `key` to `value`

  fluent: (key, value) ->
    object = @clone()
    object[key] = value
    return object

###################################################################################
# setters and defaults

  _allowedColumns: []
  allowedColumns: (columns) ->
    @fluent '_allowedColumns', @_allowedColumns.concat(columns)

  # TODO no use for that yet
  # _primaryKey: 'id'
  # primaryKey: (arg) ->
  #   @fluent '_primaryKey', arg

  _returnFirst: false
  returnFirst: (arg = true) ->
    @fluent '_returnFirst', arg

  table: (arg) ->
    @fluent('_table', arg)
      .fluent '_mohair', @_mohair.table arg

  debug: (arg) ->
    @fluent '_debug', arg

###################################################################################
# pipelining

  _beforeInsert: []
  beforeInsert: (args...) ->
    @fluent '_beforeInsert', @_beforeInsert.concat(args)

  _afterInsert: []
  afterInsert: (args...) ->
    @fluent '_afterInsert', @_afterInsert.concat(args)

  _beforeUpdate: []
  beforeUpdate: (args...) ->
    @fluent '_beforeUpdate', @_beforeUpdate.concat(args)

  # run on the records returned by an update
  _afterUpdate: []
  afterUpdate: (args...) ->
    @fluent '_afterUpdate', @_afterUpdate.concat(args)

  # run on the records returned by a delete
  _afterDelete: []
  afterDelete: (args...) ->
    @fluent '_afterUpdate', @_afterUpdate.concat(args)

  _afterSelect: []
  afterSelect: (args...) ->
    @fluent '_afterSelect', @_afterSelect.concat(args)

###################################################################################
# the underlying mohair query builder instance

  _mohair: helpers.defaultMohair

  # implementation of sql-fragment interface

  sql: (escape) ->
    @_mohair.sql(escape)
  params: ->
    @_mohair.params()

  # pass through to mohair:

  raw: (args...) ->
    @_mohair.raw args...

  where: (args...) ->
    @fluent '_mohair', @_mohair.where args...
  having: (args...) ->
    @fluent '_mohair', @_mohair.having args...
  join: (args...) ->
    @fluent '_mohair', @_mohair.join args...
  select: (args...) ->
    @fluent '_mohair', @_mohair.select args...
  limit: (arg) ->
    @fluent '_mohair', @_mohair.limit arg
  offset: (arg) ->
    @fluent '_mohair', @_mohair.offset arg
  order: (arg) ->
    @fluent '_mohair', @_mohair.order arg
  group: (arg) ->
    @fluent '_mohair', @_mohair.group arg
  with: (arg) ->
    @fluent '_mohair', @_mohair.with arg
  returning: (args...) ->
    @fluent '_mohair', @_mohair.returning args...

###################################################################################
# connection

  connection: (arg) ->
    @fluent '_connection', arg

  getConnection: (cb) ->
    connection = @_connection
    debug = @_debug

    unless connection?
      throw new Error "the method you are calling requires a call to connection() before it"

    new Promise (resolve, reject) ->
      if 'function' is typeof connection
        return connection (err, result, realDone) ->
          done = ->
            debug?(
              event: 'connection .done() called'
              connection: connection
            )
            realDone()
          if err?
            done?()
            return reject err
          debug?(
            method: 'getConnection'
            connection: result
            isNewConnection: true
          )
          resolve
            connection: result
            done: done

      debug?(
        method: 'getConnection'
        connection: connection
        isNewConnection: false
      )
      resolve
        connection: connection

###################################################################################
# nice promise based wrapper around node-postgres

  wrapInConnection: (block) ->
    @getConnection().then ({connection, done}) ->
      block(connection).finally ->
        done?()

  query: (sql, params) ->
    @debug?(
      method: 'query'
      sql: sql
      params: params
    )
    @wrapInConnection (connection) ->
      new Promise (resolve, reject) ->
        connection.query sql, params, (err, results) ->
          if err?
            return reject err
          resolve results

  wrapInTransaction: (block) ->
    that = this
    @wrapInConnection (connection) ->
      thatWithConnection = that.connection(connection)
      that.debug?(
        event: 'transaction start'
      )
      thatWithConnection.query('BEGIN;')
        .then ->
          block connection
        .then (result) ->
          that.debug?(
            event: 'transaction commit'
          )
          thatWithConnection.query('COMMIT;').then ->
            result
        .catch (error) ->
          that.debug?(
            event: 'transaction rollback'
            error: error
          )
          thatWithConnection.query('ROLLBACK;').then ->
            Promise.reject error

###################################################################################
# command: these functions have side effects

  insert: (recordOrRecords) ->
    that = this

    isArray = Array.isArray recordOrRecords

    if isArray
      @_debug?(
        method: 'insert'
        records: recordOrRecords
      )
    else
      @_debug?(
        method: 'insert'
        record: recordOrRecords
      )

    returnFirst = not isArray
    records = if isArray then recordOrRecords else [recordOrRecords]

    beforeInsert = (record) ->
      helpers.runPipeline that, that._beforeInsert, record

    Promise.all(records.map beforeInsert).then (processedArray) ->
      cleanArray = processedArray.map (record) ->
        helpers.pick record, that._allowedColumns

      query = that._mohair.insert cleanArray
      sql = helpers.replacePlaceholders query.sql()

      that.query(sql, query.params()).then (results) ->
        helpers.afterQuery that, returnFirst, that._afterInsert, results

  update: (update) ->
    that = this

    helpers.runPipeline(that, that._beforeUpdate, update).then (processedData) ->
      cleanData = helpers.pick processedData, that._allowedColumns

      query = that._mohair.update cleanData
      sql = helpers.replacePlaceholders query.sql()

      that.query(sql, query.params()).then (results) ->
        helpers.afterQuery that, that._returnFirst, that._afterUpdate, results

  delete: ->
    that = this

    query = that._mohair.delete()
    sql = helpers.replacePlaceholders query.sql()

    that.query(sql, query.params()).then (results) ->
      helpers.afterQuery that, that._returnFirst, that._afterDelete, results

###################################################################################
# query

  find: (arg) ->
    if arg?
      throw new Error "you called .find() with an argument but .find() ignores all arguments. .find() returns a promise! maybe you wanted to call the promise instead: .find().then(function(result) { ... })"

    that = this

    sql = helpers.replacePlaceholders that.sql()

    that.query(sql, that.params()).then (results) ->
      helpers.afterQuery that, that._returnFirst, that._afterSelect, results

  first: (arg) ->
    if arg?
      throw new Error "you called .first() with an argument but .first() ignores all arguments. .first() returns a promise! maybe you wanted to call the promise instead: .first().then(function(result) { ... })"

    @limit(1)
      .returnFirst()
      .find()

  exists: (arg) ->
    if arg?
      throw new Error "you called .exists() with an argument but .exists() ignores all arguments. .exists() returns a promise! maybe you wanted to call the promise instead: .exists().then(function(result) { ... })"

    query = @_mohair.limit(1)

    sql = helpers.replacePlaceholders query.sql()

    that.query(sql, query.params()).then (results) ->
      results.rows? and results.rows.length isnt 0

###################################################################################
# helper functions

  # call a one-off function as if it were part of mesa
  call: (f, args...) ->
    f.apply @, args

  helpers: helpers
