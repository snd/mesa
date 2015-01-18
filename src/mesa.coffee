mohair = require 'mohair'
Promise = require 'bluebird'
_ = require 'lodash'

################################################################################
# helpers

helpers = {}

# escape that handles table schemas correctly:
# schemaAwareEscape('someschema.users') -> '"someschema"."users"
helpers.schemaAwareEscape = (string) ->
  string.split('.').map((str) -> "\"#{str}\"").join '.'

helpers.defaultMohair = mohair
  .escape(helpers.schemaAwareEscape)
  # return everything by default
  .returning('*')

# TODO better name
helpers.replacePlaceholders = (sql) ->
  # replace ?, ?, ... with $1, $2, ...
  index = 1
  sql.replace /\?/g, -> '$' + index++

helpers.ignoredArgumentWarning = (receiver) ->
  "you called #{receiver} with an argument but #{receiver} ignores all arguments. #{receiver} returns a promise and maybe you wanted to call that promise instead: #{receiver}.then(function(result) { ... })"

helpers.normalizeLink = (leftTable, rightTable, immutableLink) ->
  leftTableName = leftTable.getTable()
  rightTableName = rightTable.getTable()

  link = if immutableLink? then _.clone immutableLink else {}

  link.forward ?= true
  link.first ?= false

  unless link.left?
    if link.forward
      # primary key
      link.left = leftTable.getPrimaryKey()
    else
      # foreign key
      unless rightTableName?
        # TODO fix error message
        throw new Error 'default for embed option `thisKey` requires call to .table(name) on this table'
      link.left = rightTableName + '_' + rightTable.getPrimaryKey()

  unless link.right?
    if link.forward
      # foreign key
      unless leftTableName?
        # TODO fix error message
        throw new Error 'default for embed option `otherKey` requires call to .table(name) on other table'
      link.right = leftTableName + '_' + leftTable.getPrimaryKey()
    else
      # primary key
      link.right = rightTable.getPrimaryKey()

  if link.as is true
    unless rightTableName?
      # TODO fix error message
      throw new Error 'default for embed option `as` requires call to .table(name) on other table'
    link.as = rightTableName
    unless link.first
      link.as += 's'

  return link

# returns a list of tables with complete links between them
# TODO error handling for malformed argument lists
helpers.normalizeIncludeArguments = (args...) ->
  # some state that will be modified by the loop below
  normalized = []
  leftTable = null
  link = null

  lastIndex = args.length - 1

  args.forEach (arg, index) ->
    if helpers.isInstance arg
      if leftTable?
        # last results are always included
        link = if link? then _.clone(link) else {}
        if index is lastIndex
          link.as ?= true
        rightTable = arg
        link = helpers.normalizeLink leftTable, rightTable, link
        link.table = rightTable
        normalized.push link
        # dont use the link again
        link = null

      # in any case set the next leftTable
      leftTable = arg
    else
      link = arg

  return normalized

################################################################################
# core

Mesa = (source) ->
  if source
    # only copy OWN properties.
    # don't copy properties on the prototype.
    # OWN properties are just non-default values and user defined methods.
    # OWN properties tend to be very few for most queries.
    for own k, v of source
      this[k] = v
  return this

Mesa.prototype =

  # the magic behind mohair's fluent interface:
  # after benchmarking several possible solutions
  # and even prototypically inheriting from the calling objects
  # i found that
  # splitting the properties
  # and
  # is the most time and space efficient solution.
  # in reality only very few properties
  #
  # with prototypical inheritance produces a long prototype chain.
  # long prorotypical inheritance chains are not performant.
  # it also prevents the entire chain from being garbage collected
  # which requires a lot of space.
  #
  # all intermediaries can be safely garbage collected

  fluent: (key, value) ->
    next = new Mesa @
    next[key] = value
    return next

  # call a one-off function as if it were part of mesa
  call: (f, args...) ->
    result = f.apply @, args
    unless helpers.isInstance result
      throw new Error 'the function passed to .call() must return a mesa-object'
    return result

  when: (condition, fn, args...) ->
    if condition then @call fn, args... else @

  each: (arrayOrObject, fn, args...) ->
    callback = (that, value, indexOrKey) ->
      result = fn.call that, value, indexOrKey, args...
      unless helpers.isInstance result
        throw new Error 'the function passed to .each() must return a mesa-object'
      result
    _.reduce arrayOrObject, callback, this

  _returnFirst: false
  returnFirst: (arg = true) ->
    @fluent '_returnFirst', arg

  debug: (arg) ->
    @fluent '_debug', arg

################################################################################
# mass assignment protection

  _allowed: []
  allow: (columns...) ->
    @fluent '_allowed', _.flatten(columns)

  _isUnsafe: false
  unsafe: (isUnsafe = true) ->
    @fluent '_isUnsafe', isUnsafe

  pickAllowed: (record) ->
    if @_isUnsafe
      return record
    if @_allowed.length is 0
      throw new Error [
        'no columns are allowed.'
        'this will make .update() or .insert() fail.'
        'call .allow(columns...) with at least one column before .insert() or .update().'
        'alternatively call .unsafe() before to disable mass assignment protection altogether.'
      ].join(' ')
    _.pick record, @_allowed

################################################################################
# pass throughs to the underlying mohair query builder instance

  _mohair: helpers.defaultMohair

  # implementation of sql-fragment interface

  sql: (escape) ->
    @_mohair.sql(escape)
  params: ->
    @_mohair.params()

  raw: (args...) ->
    @_mohair.raw args...

  table: (arg) ->
    @fluent '_mohair', @_mohair.table arg

  getTable: ->
    @_mohair.getTable()

  from: (args...) ->
    @fluent '_mohair', @_mohair.from args...

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
  distinct: (args...) ->
    @fluent '_mohair', @_mohair.distinct args...
  for: (args...) ->
    @fluent '_mohair', @_mohair.for args...
  window: (args...) ->
    @fluent '_mohair', @_mohair.window args...

################################################################################
# set and get connection

  setConnection: (arg) ->
    typeofArg = typeof arg
    unless ('function' is typeof arg) or (('object' is typeof arg) and arg.query?)
      throw new Error '.setConnection() must be called with either a connection object or a function that takes a callback and calls it with a connection'
    @fluent '_connection', arg

  getConnection: (arg) ->
    that = @
    if arg?
      throw new Error helpers.ignoredArgumentWarning '.getConnection()'
    connection = @_connection
    debug = @_debug

    unless connection?
      return Promise.reject new Error "the method you are calling requires a call to .setConnection() before it"

    new Promise (resolve, reject) ->
      if 'function' is typeof connection
        return connection (err, result, realDone) ->
          done = ->
            debug? 'connection', 'done', {}, {connection: connection}, that
            realDone()
          if err?
            done?()
            return reject err
          debug? 'connection', 'fresh', {}, {
            connection: result
            done: done
          }, that
          resolve
            connection: result
            done: done

      debug? 'connection', 'reuse', {}, {connection: connection}, that
      resolve
        connection: connection

################################################################################
# promise wrapper around node-postgres

  wrapInConnection: (block) ->
    @getConnection().then ({connection, done}) ->
      block(connection).finally ->
        done?()

  query: (sqlOrFragment, params) ->
    if mohair.implementsSqlFragmentInterface sqlOrFragment
      sql = helpers.replacePlaceholders sqlOrFragment.sql helpers.schemaAwareEscape
      if params?
        throw new Error 'query with sql fragment as first arg is not allowed to have a second arg'
      params = sqlOrFragment.params()
    else
      sql = sqlOrFragment
    that = @
    debug = @_debug
    @wrapInConnection (connection) ->
      new Promise (resolve, reject) ->
        debug? 'query', 'before', {
          sql: sql,
          params: params
        }, {
          connection: connection
        }, that
        connection.query sql, params, (err, results) ->
          debug? 'query', 'after', {
            sql: sql
            params: params
          }, {
            connection: connection
            err: err
            results: results
          }, that
          if err?
            return reject err
          resolve results

  wrapInTransaction: (block) ->
    that = this
    debug = @_debug
    @wrapInConnection (connection) ->
      withConnection = that.setConnection(connection)
      debug? 'transaction', 'begin', {}, {connection: connection, block: block}, that
      withConnection.query('BEGIN;')
        .then ->
          block connection
        .then (result) ->
          debug? 'transaction', 'commit', {}, {connection: connection, block: block}, that
          withConnection.query('COMMIT;').then ->
            result
        .catch (error) ->
          debug? 'transaction', 'rollback', {error: error}, {
            connection: connection
            block: block
          }, that
          withConnection.query('ROLLBACK;').then ->
            Promise.reject error

################################################################################

  runQueue: (queue, value) ->
    context = @
    reducer = (soFar, step) ->
      soFar.then step.bind(context)
    queue.reduce reducer, Promise.resolve value

################################################################################
# what happens after the promise returned by .query(sql, params) is resolved
# but before the promise returned by the calling function
# (.select(), insert.(), ...) is resolved.

  afterQuery: (results, options) ->
    that = this
    debug = @_debug
    rows = results.rows
    unless rows
      return results

    debug? 'after-query', 'before-queue', {rows: rows}, options, that
    @runQueue(options.after, rows)
      .map @runQueue.bind(@, options.afterEach)
      .then (rows) ->
        debug? 'after-query', 'after-queue', {rows: rows}, options, that
        if options.returnFirst
          rows[0]
        else
          rows

################################################################################
# command: these functions have side effects

  insert: (args...) ->
    that = this
    debug = @_debug

    records = _.flatten args

    if records.length is 0
      throw new Error 'no records to insert'

    returnFirst = args.length is 1 and not Array.isArray(args[0])

    debug? 'insert', 'before-queue', {records: records}, {}, that

    @runQueue(@_queueBeforeInsert, records)
      .map @runQueue.bind(@, @_queueBeforeEachInsert)
      .then (records) ->
        debug? 'insert', 'after-queue', {records: records}, {}, that
        records.forEach (record, index) ->
          if Object.keys(record).length is 0
            throw new Error "insert would fail because record at index #{index} is empty after processing before queue"

        that.query(that._mohair.insert(records)).then (results) ->
          that.afterQuery(results,
            returnFirst: returnFirst
            after: that._queueAfterInsert
            afterEach: that._queueAfterEachInsert
          )

  update: (update) ->
    that = this
    debug = @_debug

    debug? 'update', 'before-queue', {update: update}, {}, that

    @runQueue(@_queueBeforeEachUpdate, update).then (update) ->
      debug? 'update', 'after-queue', {update: update}, {}, that

      that.query(that._mohair.update(update)).then (results) ->
        that.afterQuery results,
          returnFirst: that._returnFirst
          after: that._queueAfterUpdate
          afterEach: that._queueAfterEachUpdate

  delete: ->
    if arg?
      throw new Error helpers.ignoredArgumentWarning '.delete()'
    that = this

    that.query(that._mohair.delete()).then (results) ->
      that.afterQuery results,
        returnFirst: that._returnFirst
        after: that._queueAfterDelete
        afterEach: that._queueAfterEachDelete

################################################################################
# query: these functions have no side effects

  find: (arg) ->
    if arg?
      throw new Error helpers.ignoredArgumentWarning '.find()'

    that = this

    that.query(this).then (results) ->
      that.afterQuery results,
        returnFirst: that._returnFirst
        after: that._queueAfterSelect
        afterEach: that._queueAfterEachSelect

  first: (arg) ->
    if arg?
      throw new Error helpers.ignoredArgumentWarning '.first()'

    @limit(1)
      .returnFirst()
      .find()

  exists: (arg) ->
    if arg?
      throw new Error helpers.ignoredArgumentWarning '.exists()'

    @query(@_mohair.limit(1)).then (results) ->
      results.rows? and results.rows.length isnt 0

################################################################################
# primary key (used by embeds)

  _primaryKey: 'id'
  primaryKey: (arg) ->
    @fluent '_primaryKey', arg
  getPrimaryKey: ->
    @_primaryKey

################################################################################
# embed

  # TODO REFACTOR this function works and is well tested
  # but a bit of a complicated mess of side effects and promises
  baseEmbed: (originalRecords, includes) ->
    # regardless of how we branch off we keep them in buckets
    # buckets always contains the records of the last layer
    # that are connected to the records in the starting table
    groupedByFirst = null
    prevRecords = originalRecords

    reducer = (soFar, include) ->
      # run in series
      # wait for previous include steps to continue
      soFar.then ->
        condition = {}
        condition[include.right] = _.pluck prevRecords, include.left

        include.table
          .where(condition)
          .find()
          .then (nextRecords) ->
            groupedByCurrent = _.groupBy nextRecords, include.right

            groupedByFirst =
              unless groupedByFirst?
                groupedByCurrent
              else
                _.mapValues groupedByFirst, (records) ->
                  # forward bucket to the next layer
                  # by replacing records by the records they are
                  # associated with
                  _.reduce records, ((acc, record) ->
                    records = groupedByCurrent[record[include.left]]
                    if records? then acc.concat records else acc
                  ), []

            if include.as?
              # embed this layer (currently in buckets) into the original records
              originalRecords.forEach (record) ->
                group = groupedByFirst[record[includes[0].left]] or []
                if include.first
                  if group[0]?
                    record[include.as] = group[0]
                else
                  record[include.as] = group
            prevRecords = nextRecords

    # run include steps in series
    includes.reduce(reducer, Promise.resolve()).then ->
      # finally return the original records
      originalRecords

  embed: (records, args...) ->
    @baseEmbed records, helpers.normalizeIncludeArguments @, args...

  include: (args...) ->
    @queueAfter _.partialRight @embed, args...

################################################################################
# automatic construction of setters and properties for queue:
# (automating this prevents copy & paste errors)

# TODO better name
payload = (f, args...) ->
  if args.length is 0 then f else _.partialRight f, args...

setQueueProperties = (object, suffix) ->
  setterPropertyName = 'queue' + suffix
  dataPropertyName = '_' + setterPropertyName
  object[dataPropertyName] = []
  object[setterPropertyName] = (args...) ->
    @fluent dataPropertyName, @[dataPropertyName].concat [payload args...]

# queueBeforeInsert, queueBeforeEachInsert
# queueBeforeEachUpdate (just that because the update is a single object/record)

setQueueProperties(Mesa.prototype, 'BeforeInsert')
setQueueProperties(Mesa.prototype, 'BeforeEachInsert')
setQueueProperties(Mesa.prototype, 'BeforeEachUpdate')

# queueAfterSelect, queueAfterEachSelect
# queueAfterInsert, queueAfterEachInsert
# queueAfterUpdate, queueAfterEachUpdate
# queueAfterDelete, queueAfterEachDelete

for phase in ['Select', 'Insert', 'Update', 'Delete']
  setQueueProperties(Mesa.prototype, 'After' + phase)
  setQueueProperties(Mesa.prototype, 'AfterEach' + phase)

Mesa.prototype.queueBeforeEach = (args...) ->
  object = new Mesa @
  ['Insert', 'Update'].forEach (phase) ->
    propertyName = '_queueBeforeEach' + phase
    object[propertyName] = object[propertyName].concat [payload args...]
  return object

Mesa.prototype.queueAfter = (args...) ->
  object = new Mesa @
  ['Select', 'Insert', 'Update', 'Delete'].forEach (phase) ->
    propertyName = '_queueAfter' + phase
    object[propertyName] = object[propertyName].concat [payload args...]
  return object

Mesa.prototype.queueAfterEach = (args...) ->
  object = new Mesa @
  ['Select', 'Insert', 'Update', 'Delete'].forEach (phase) ->
    propertyName = '_queueAfterEach' + phase
    object[propertyName] = object[propertyName].concat [payload args...]
  return object

################################################################################
# exports

Mesa.prototype.isInstance = helpers.isInstance = (object) ->
  object instanceof Mesa

Mesa.prototype.helpers = helpers

# put mesaBaseProperties one step away from the exported object in the prototype chain
# such that mesa.clone() does not copy the mesaBase properties.
# mesa.clone() just copies OWN properties.
# user-added methods are OWN properties and get copied.
# this keeps the copies small which is nice for performance (memory and cpu)
# and makes inspecting the `this` objects more pleasant as they
# only contain relevant state.
mesa = new Mesa

module.exports = mesa
  # enable mass assignment protection
  .queueBeforeEach(mesa.pickAllowed)
