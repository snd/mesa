mohair = require 'mohair'
Promise = require 'bluebird'

# escape that handles table schemas correctly:
# schemaAwareEscape('someschema.users') -> '"someschema"."users"
schemaAwareEscape = (string) ->
  string.split(".").map((str) -> "\"#{str}\"").join '.'

defaultMohair = mohair
  .escape(schemaAwareEscape)
  # return everything by default
  .returning('*')

# async: hooks can return promises !
runPipeline = (context, pipeline, record) ->
  reducer = (soFar, step) ->
    soFar.then step.bind(context)
  pipeline.reduce reducer, Promise.resolve record

afterQuery = (context, returnFirst, pipeline, queryResults) ->
  if queryResults.rows?
    processRow = (row) ->
      runPipeline context, pipeline, row
    Promise.all(queryResults.rows.map processRow).then (processedRows) ->
      if returnFirst
        processedRows[0]
      else
        processedRows
  else
    results

module.exports =

###################################################################################
# core

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

  _mohair: defaultMohair

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

    unless connection?
      # TODO StateError
      throw new Error "the method you are calling requires a call to connection() before it"
    if 'function' is typeof connection
      connection cb
      return
    setTimeout ->
      cb null, connection

  query: (sql, params) ->
    getConnection = @getConnection.bind(@)

    @_debug?(
      method: 'query'
      sql: sql
      params: params
    )

    new Promise (resolve, reject) ->
      # thankfully the only piece of ugly callback code in all of mesa ;-)
      getConnection (err, connection, done) ->
        if err?
          done?()
          reject err
          return
        connection.query sql, params, (err, results) ->
          done?()
          if err?
            reject err
            return
          resolve results

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
      runPipeline that, that._beforeInsert, record

    Promise.all(records.map beforeInsert).then (processedArray) ->
      cleanArray = processedArray.map (record) ->
        that.pickAllowedColumns record

      query = that._mohair.insert cleanArray
      sql = that.replacePlaceholders query.sql()

      that.query(sql, query.params()).then (results) ->
        afterQuery that, returnFirst, that._afterInsert, results

  update: (update) ->
    that = this

    runPipeline(that, that._beforeUpdate, update).then (processedData) ->
      cleanData = that.pickAllowedColumns processedData

      query = that._mohair.update cleanData
      sql = that.replacePlaceholders query.sql()

      that.query(sql, query.params()).then (results) ->
        afterQuery that, that._returnFirst, that._afterUpdate, results

  delete: ->
    that = this

    query = that._mohair.delete()
    sql = that.replacePlaceholders query.sql()

    that.query(sql, query.params()).then (results) ->
      afterQuery that, that._returnFirst, that._afterDelete, results

###################################################################################
# query

  find: (arg) ->
    if arg?
      throw new Error "you called `.find()` with an argument but `.find()` ignores all arguments. find returns a promise! maybe you wanted to call the promise instead: `find().then(function(result) { ... })`"

    that = this

    sql = that.replacePlaceholders that.sql()

    that.query(sql, that.params()).then (results) ->
      afterQuery that, that._returnFirst, that._afterSelect, results

  first: ->
    @limit(1)
      .returnFirst()
      .find()

  exists: ->
    query = @_mohair.limit(1)

    sql = @replacePlaceholders query.sql()

    that.query(sql, query.params()).then (results) ->
      results.rows? and results.rows.length isnt 0

###################################################################################
# helper functions

  # call a one-off function as if it were part of mesa
  call: (f, args...) ->
    f.apply @, args

  replacePlaceholders: (sql) ->
    # replace ?, ?, ... with $1, $2, ...
    index = 1
    sql.replace /\?/g, -> '$' + index++

  pickAllowedColumns: (record) ->
    picked = {}
    @_allowedColumns.forEach (column) ->
      if (column of record)
        picked[column] = record[column]
    return picked
