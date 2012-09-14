mohair = require 'mohair'
_ = require 'underscore'

module.exports = class

    # fluent
    # ======

    # returns a new Model instance with key set to value

    set: (key, value) ->
        object = new @constructor
        object._parent = @
        state = {}
        state[key] = value
        object._state = state
        object

    # setters

    connection: (connection) -> @set '_connection', connection

    attributes: (attributes) -> @set '_attributes', attributes

    # mohair

    table: (table) -> @set('_table', table)._modifyMohair (m) -> m.table table

    where: (args...) -> @_modifyMohair (m) -> m.where args...

    select: (sql) -> @_modifyMohair (m) -> m.select sql

    join: (sql) -> @_modifyMohair (m) -> m.join sql

    limit: (limit) -> @_modifyMohair (m) -> m.limit limit

    offset: (offset) -> @_modifyMohair (m) -> m.offset offset

    order: (order) -> @_modifyMohair (m) -> m.order order

    group: (group) -> @_modifyMohair (m) -> m.group group

    # not fluent
    # ==========

    # search for a key in the parent chain

    get: (key) ->
        return @_state[key] if @_state? and @_state[key]?
        return null if not @_parent?
        @_parent.get key

    getTable: -> @get '_table'

    _modifyMohair: (f) -> @set '_mohair', f @getMohair()

    getConnection: (cb) ->
        connection = @get '_connection'
        unless connection?
            throw new Error 'no connection. please call connection'
        return connection cb if 'function' is typeof connection
        process.nextTick -> cb null, connection

    getMohair: (cb) ->
        @_state = {} if not @_state?
        m = @get '_mohair'
        m = @_state._mohair =  mohair unless m?
        m

    # command
    # -------

    insert: (data, cb) ->
        attributes = @get '_attributes'

        throw new Error 'please call attributes' unless attributes?

        safeData =
            if Array.isArray data
                data.map (x) -> _.pick x, attributes
            else
                _.pick data, attributes

        m = @getMohair()
        q = m.insert safeData
        sql = @postgresPlaceholders q.sql() + ' RETURNING id'
        params = q.params()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, params, (err, results) ->
                return cb err if err?

                cb null, if Array.isArray data
                    _.pluck results.rows, 'id'
                else
                    results.rows[0].id

    delete: (cb) ->
        m = @getMohair()
        q = m.delete()
        sql = @postgresPlaceholders q.sql()
        params = q.params()

        @getConnection (err, connection) ->
            return cb err if err?
            connection.query sql, params, cb

    update: (data, cb) ->
        attributes = @get '_attributes'

        throw new Error 'please call attributes' unless attributes?

        m = @getMohair()
        q = m.update _.pick data, attributes
        sql = @postgresPlaceholders q.sql()
        params = q.params()

        @getConnection (err, connection) =>
            return cb err if err?
            connection.query sql, params, cb

    # query
    # -----

    first: (cb) ->
        m = @getMohair()
        sql = @postgresPlaceholders m.sql()
        params = m.params()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, params, (err, results) =>
                return cb err if err?

                cb null, results.rows[0]

    find: (cb) ->
        m = @getMohair()
        sql = @postgresPlaceholders m.sql()
        params = m.params()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, params, (err, results) =>
                return cb err if err?

                cb null, results.rows

    exists: (cb) ->
        m = @getMohair()
        sql = @postgresPlaceholders m.sql()
        params = m.params()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, params, (err, results) ->
                return cb err if err?
                cb null, results.rows.length isnt 0

    # misc
    # ====

    postgresPlaceholders: (sql) ->
        # replace ? with $1, $2, ...
        index = 1
        sql.replace /\?/g, -> '$' + index++
