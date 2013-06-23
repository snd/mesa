_ = require 'underscore'

mesa = require './mesa'

# for now this is just an extension of the core mesa

module.exports = Object.create mesa

# enable postgres escaping
mohair = module.exports._mohair.escape((string) -> "\"#{string}\"")
module.exports._mohair = mohair
module.exports._originalMohair = mohair

module.exports.getConnection = (cb) ->
    connection = @_connection
    unless connection?
        throw new Error "the method you are calling requires a call to connection() before it"
    return connection cb if 'function' is typeof connection
    process.nextTick -> cb null, connection

module.exports.replacePlaceholders = (sql) ->
    # replace ?, ?, ... with $1, $2, ...
    index = 1
    sql.replace /\?/g, -> '$' + index++

module.exports.returning = (arg) ->
        throw new Error 'must be a string' unless 'string' is typeof arg
        throw new Error 'must not be the empty string' if arg.length is 0
        @set '_returning', arg

# command
# -------

module.exports.insert = (data, cb) ->
    unless @_attributes?
        throw new Error 'insert() requires call to attributes() before it'

    cleanData = _.pick data, @_attributes
    if Object.keys(cleanData).length is 0
        throw new Error 'nothing to insert'

    query = @_mohair.insert cleanData

    returning = if @_returning then @_returning else @_primaryKey
    sql = @replacePlaceholders query.sql() + " RETURNING #{returning}"

    @getConnection (err, connection, done) =>
        return cb err if err?

        connection.query sql, query.params(), (err, results) =>
            return cb err if err?

            row = results.rows[0]

            done?()

            cb null, if @_returning? then row else row[@_primaryKey]


module.exports.insertMany = (array, cb) ->
    unless @_attributes?
        throw new Error 'insertMany() requires call to attributes() before it'

    query = @_mohair.insertMany array.map (x) => _.pick x, @_attributes
    returning = if @_returning then @_returning else @_primaryKey
    sql = @replacePlaceholders query.sql() + " RETURNING #{returning}"

    @getConnection (err, connection, done) =>
        return cb err if err?

        connection.query sql, query.params(), (err, results) =>
            return cb err if err?

            done?()

            cb null, if @_returning? then results.rows else _.pluck results.rows, @_primaryKey

module.exports.delete = (cb) ->
    query = @_mohair.delete()
    sql = @replacePlaceholders query.sql()

    @getConnection (err, connection, done) ->
        return cb err if err?

        done?()

        connection.query sql, query.params(), cb

module.exports.update = (updates, cb) ->
    unless @_attributes?
        throw new Error 'update() requires call to attributes() before it'

    cleanUpdates = _.pick updates, @_attributes
    throw new Error 'nothing to update' if Object.keys(cleanUpdates).length is 0

    query =  @_mohair.update cleanUpdates
    sql = @replacePlaceholders query.sql()
    sql += " RETURNING #{@_returning}" if @_returning?

    @getConnection (err, connection, done) =>
        return cb err if err?

        connection.query sql, query.params(), (err, results) =>
            return cb err if err?
            done?()
            return cb null, results unless @_returning?
            return cb null, results.rows

# query
# -----

module.exports.first = (cb) ->
    query =  @_mohair
    sql = @replacePlaceholders query.sql()

    @getConnection (err, connection, done) =>
        return cb err if err?

        connection.query sql, query.params(), (err, results) =>
            return cb err if err?

            record = results.rows[0]

            unless record?
                done?()
                cb null, null
                return

            @_getIncludes connection, [record], (err, withIncludes) =>
                return cb err if err?
                done?()
                cb null, withIncludes[0]

module.exports.find = (cb) ->
    sql = @replacePlaceholders @sql()

    @getConnection (err, connection, done) =>
        return cb err if err?

        connection.query sql, @params(), (err, results) =>
            return cb err if err?

            records = results.rows

            if records.length is 0
                done?()
                cb null, []
                return

            @_getIncludes connection, records, (err, withIncludes) =>
                return cb err if err?

                done?()

                cb null, withIncludes

module.exports.exists = (cb) ->
    query =  @_mohair
    sql = @replacePlaceholders query.sql()

    @getConnection (err, connection, done) =>
        return cb err if err?

        connection.query sql, query.params(), (err, results) ->
            return cb err if err?

            done?()

            cb null, results.rows.length isnt 0
