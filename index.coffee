mohair = require 'mohair'
_ = require 'underscore'

# methods marked as FLUENT return a new instance

module.exports = class

    # setters
    # -------

    # FLUENT
    # returns a new instance with key set to value

    set: (key, value) ->
        object = new @constructor
        object._parent = @
        state = {}
        state[key] = value
        object._state = state
        object

    # FLUENT

    connection: (connection) -> @set '_connection', connection

    # FLUENT

    attributes: (attributes) -> @set '_attributes', attributes

    # getters
    # -------

    # search for a key in the parent chain

    get: (key) ->
        return @_state[key] if @_state? and @_state[key]?
        return null if not @_parent?
        @_parent.get key

    getTable: -> @get '_table'

    getConnection: (cb) ->
        connection = @get '_connection'
        unless connection?
            throw new Error "the method you are calling requires call to connection() before it"
        return connection cb if 'function' is typeof connection
        process.nextTick -> cb null, connection

    # mohair
    # ------

    getMohair: (cb) ->
        @_state = {} if not @_state?
        m = @get '_mohair'
        # set mohair if it isn't already
        m = @_state._mohair = mohair unless m?
        m

    _modifyMohair: (f) -> @set '_mohair', f @getMohair()

    # FLUENT

    table: (table) -> @set('_table', table)._modifyMohair (m) -> m.table table

    where: (args...) -> @_modifyMohair (m) -> m.where args...
    select: (sql) -> @_modifyMohair (m) -> m.select sql
    join: (sql) -> @_modifyMohair (m) -> m.join sql
    limit: (limit) -> @_modifyMohair (m) -> m.limit limit
    offset: (offset) -> @_modifyMohair (m) -> m.offset offset
    order: (order) -> @_modifyMohair (m) -> m.order order
    group: (group) -> @_modifyMohair (m) -> m.group group

    # commands
    # --------

    insert: (data, cb) ->
        attributes = @get '_attributes'
        unless attributes?
            throw new Error 'insert() requires call to attributes() before it'

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

        unless attributes?
            throw new Error 'update() requires call to attributes() before it'

        m = @getMohair()
        q = m.update _.pick data, attributes
        sql = @postgresPlaceholders q.sql()
        params = q.params()

        @getConnection (err, connection) =>
            return cb err if err?
            connection.query sql, params, cb

    # queries
    # -------

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
    # ----

    postgresPlaceholders: (sql) ->
        # replace ? with $1, $2, ...
        index = 1
        sql.replace /\?/g, -> '$' + index++
