_ = require 'underscore'

mesa = require './mesa'

# for now this is just an extension of the core mesa

module.exports = Object.create mesa

# enable postgres escaping
mohair = module.exports._mohair.escape (string) -> string.split(".").map((str) -> "\"#{str}\"").join '.'
module.exports._mohair = mohair
module.exports._originalMohair = mohair

module.exports.getConnection = (cb) ->
    connection = this._connection
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
    this.set '_returning', arg

# command
# -------

module.exports.insert = (data, cb) ->
    self = this

    self.assertConnection()
    self.assertTable()
    self.assertAttributes()

    cleanData = _.pick data, self._attributes
    if Object.keys(cleanData).length is 0
        throw new Error 'nothing to insert'

    query = self._mohair.insert cleanData

    returning = if self._returning then self._returning else self._primaryKey
    sql = self.replacePlaceholders query.sql() + " RETURNING #{returning}"

    self.getConnection (err, connection, done) ->
        if err?
            done?()
            cb err
            return

        connection.query sql, query.params(), (err, results) ->
            if err?
                done?()
                cb err
                return

            row = results.rows[0]

            done?()

            cb null, if self._returning?
                row
            else
                row[self._primaryKey]


module.exports.insertMany = (array, cb) ->
    self = this

    self.assertConnection()
    self.assertTable()
    self.assertAttributes()

    query = self._mohair.insertMany array.map (x) => _.pick x, self._attributes
    returning = if self._returning then self._returning else self._primaryKey
    sql = self.replacePlaceholders query.sql() + " RETURNING #{returning}"

    self.getConnection (err, connection, done) ->
        if err?
            done?()
            cb err
            return

        connection.query sql, query.params(), (err, results) ->
            if err?
                done?()
                cb err
                return

            done?()

            cb null, if self._returning?
                results.rows
            else
                _.pluck results.rows, self._primaryKey

module.exports.delete = (cb) ->
    self = this

    self.assertConnection()
    self.assertTable()

    query = self._mohair.delete()
    sql = self.replacePlaceholders query.sql()

    self.getConnection (err, connection, done) ->
        if err?
            done?()
            cb err
            return

        connection.query sql, query.params(), (err, results) ->
            if err?
                done?()
                cb err
                return
            done?()
            cb null, results

module.exports.update = (updates, cb) ->
    self = this

    self.assertConnection()
    self.assertTable()
    self.assertAttributes()

    cleanUpdates = _.pick updates, self._attributes
    throw new Error 'nothing to update' if Object.keys(cleanUpdates).length is 0

    query =  self._mohair.update cleanUpdates
    sql = self.replacePlaceholders query.sql()
    sql += " RETURNING #{self._returning}" if self._returning?

    self.getConnection (err, connection, done) ->
        if err?
            done?()
            cb err
            return

        connection.query sql, query.params(), (err, results) ->
            if err?
                done?()
                cb err
                return
            done?()
            return cb null, results unless self._returning?
            return cb null, results.rows

# query
# -----

module.exports.first = (cb) ->
    self = this

    self.assertConnection()

    sql = self.replacePlaceholders self.sql()
    params = self.params()

    self.getConnection (err, connection, done) ->
        if err?
            done?()
            cb err
            return

        self.hookBeforeFirst? self, connection, sql, params
        connection.query sql, params, (err, results) ->
            done?()
            self.hookAfterFirst? self, connection, sql, params, err, results

            if err?
                cb err
                return

            record = results.rows[0]

            unless record?
                cb null, null
                return

            self.hookBeforeGetIncludesForFirst? self, connection, record
            self.connection(connection)._getIncludes [record], (err, withIncludes) ->
                self.hookAfterGetIncludesForFirst? self, connection, err, withIncludes

                if err?
                    cb err
                    return
                cb null, withIncludes[0]

module.exports.find = (cb) ->
    self = this

    self.assertConnection()

    sql = self.replacePlaceholders self.sql()
    params = self.params()

    self.getConnection (err, connection, done) ->
        if err?
            done?()
            cb err
            return

        self.hookBeforeFind? self, connection, sql, params
        connection.query sql, params, (err, results) ->
            done?()
            self.hookAfterFind? self, connection, sql, params, err, results
            if err?
                cb err
                return

            records = results.rows

            if records.length is 0
                cb null, []
                return

            self.hookBeforeGetIncludesForFind? self, connection, records
            self.connection(connection)._getIncludes records, (err, withIncludes) ->
                self.hookAfterGetIncludesForFind? self, connection, err, withIncludes

                if err?
                    cb err
                    return

                cb null, withIncludes

module.exports.exists = (cb) ->
    self = this

    self.assertConnection()

    query =  self._mohair
    sql = self.replacePlaceholders query.sql()

    self.getConnection (err, connection, done) ->
        if err?
            done?()
            cb err
            return

        connection.query sql, query.params(), (err, results) ->
            if err?
                done?()
                cb err
                return

            done?()

            cb null, results.rows.length isnt 0
