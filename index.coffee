mohair = require 'mohair'
_ = require 'underscore'
async = require 'async'

# methods marked as FLUENT return a new instance

module.exports = class

    # core
    # ----

    # FLUENT
    # returns a new instance with key set to value

    set: (key, value) ->
        object = new @constructor
        object._parent = @
        state = {}
        state[key] = value
        object._state = state
        object

    # search for a key in the parent chain

    get: (key) ->
        return @_state[key] if @_state? and @_state[key]?
        return null if not @_parent?
        @_parent.get key

    # setters
    # -------

    # FLUENT

    table: (table) -> @set('_table', table)._modifyMohair (m) -> m.table table

    # FLUENT

    connection: (connection) -> @set '_connection', connection

    # FLUENT

    attributes: (attributes) -> @set '_attributes', attributes

    # getters
    # -------

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

    # where, select, join, limit, offset, order and group are all
    # FLUENT

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

        m = @getMohair()
        q = m.insert _.pick data, attributes
        sql = @postgresPlaceholders q.sql() + ' RETURNING id'
        params = q.params()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, params, (err, results) ->
                return cb err if err?

                cb null, results.rows[0].id

    insertMany: (data, cb) ->
        attributes = @get '_attributes'
        unless attributes?
            throw new Error 'insertMany() requires call to attributes() before it'

        m = @getMohair()
        q = m.insert data.map (x) -> _.pick x, attributes
        sql = @postgresPlaceholders q.sql() + ' RETURNING id'
        params = q.params()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, params, (err, results) ->
                return cb err if err?

                cb null, _.pluck results.rows, 'id'

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

                item = results.rows[0]

                return cb null, null if not item?

                @fetchIncludes connection, [item], (err, withIncludes) =>
                    return cb err if err?
                    cb null, withIncludes[0]

    find: (cb) ->
        m = @getMohair()
        sql = @postgresPlaceholders m.sql()
        params = m.params()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, params, (err, results) =>
                return cb err if err?

                items = results.rows

                return cb null, [] if items.length is 0

                @fetchIncludes connection, items, (err, withIncludes) =>
                    return cb err if err?

                    cb null, withIncludes


    exists: (cb) ->
        m = @getMohair()
        sql = @postgresPlaceholders m.sql()
        params = m.params()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, params, (err, results) ->
                return cb err if err?
                cb null, results.rows.length isnt 0

    # associations
    # ------------

    # FLUENT

    includes: (includes) -> @set '_includes', includes

    # FLUENT

    _addAssociation: (type, name, model, options) ->
        associations = _.extend {}, @get '_associations'
        associations[name] =
            type: type
            model: model
            options: options
        @set '_associations', associations

    # FLUENT

    hasOne: (name, model, options) ->
        @_addAssociation 'hasOne', name, model, options

    # FLUENT

    belongsTo: (name, model, options) ->
        @_addAssociation 'belongsTo', name, model, options

    # FLUENT

    hasMany: (name, model, options) ->
        @_addAssociation 'hasMany', name, model, options

    # FLUENT

    hasAndBelongsToMany: (name, model, options) ->
        @_addAssociation 'hasAndBelongsToMany', name, model, options

    fetchIncludes: (connection, items, cb) ->
        associations = @get '_associations'
        includes = @get '_includes'

        return cb null, items if not includes?

        includeNames = Object.keys(includes)

        throw new Error 'empty includes' if includeNames.length is 0

        includeNames.forEach (x) ->
            throw new Error "no association: #{x}" unless associations? and associations[x]?

        table = @getTable()
        throw new Error 'no table set on model' unless table?

        fetchInclude = (includeName, cb) =>
            assoc = associations[includeName]
            otherModel =
                if 'function' is typeof assoc.model then assoc.model() else assoc.model
            otherTable = otherModel.getTable()
            throw new Error 'no table set on associated model' unless otherTable?

            switch assoc.type
                when 'hasOne'
                    primaryKey = assoc.options?.primaryKey || 'id'
                    foreignKey = assoc.options?.foreignKey || "#{table}_id"

                    criterion = {}
                    criterion[foreignKey] = _.pluck items, primaryKey
                    chain = otherModel
                        .connection(connection)
                        .where(criterion)
                    if 'object' is typeof includes[includeName]
                        chain = chain.includes includes[includeName]

                    chain.find (err, associated) ->
                            return cb err if err?

                            items.forEach (item) ->
                                item[includeName] = _.detect associated, (x) ->
                                    x[foreignKey] is item[primaryKey]
                            cb null, items
                when 'belongsTo'
                    # foreign and primary keys are switched
                    primaryKey = assoc.options?.primaryKey || 'id'
                    foreignKey = assoc.options?.foreignKey || "#{otherTable}_id"

                    criterion = {}
                    criterion[primaryKey] = _.pluck items, foreignKey
                    chain = otherModel
                        .connection(connection)
                        .where(criterion)
                    if 'object' is typeof includes[includeName]
                        chain = chain.includes includes[includeName]

                    chain.find (err, associated) ->
                            return cb err if err?

                            items.forEach (item) ->
                                item[includeName] = _.detect associated, (x) ->
                                    x[primaryKey] is item[foreignKey]
                            cb null, items
                when 'hasMany'
                    # filter is the only change from hasOne
                    primaryKey = assoc.options?.primaryKey || 'id'
                    foreignKey = assoc.options?.foreignKey || "#{table}_id"

                    criterion = {}
                    criterion[foreignKey] = _.pluck items, primaryKey
                    chain = otherModel
                        .connection(connection)
                        .where(criterion)
                    if 'object' is typeof includes[includeName]
                        chain = chain.includes includes[includeName]

                    chain.find (err, associated) ->
                            return cb err if err?

                            items.forEach (item) ->
                                item[includeName] = _.filter associated, (x) ->
                                    x[foreignKey] is item[primaryKey]
                            cb null, items
                when 'hasAndBelongsToMany'
                    joinTable = assoc.options?.joinTable
                    throw new Error 'no join table' if not joinTable?

                    primaryKey = assoc.options?.primaryKey || 'id'
                    foreignKey = assoc.options?.foreignKey || "#{table}_id"
                    otherPrimaryKey = assoc.options?.otherPrimaryKey || 'id'
                    otherForeignKey = assoc.options?.otherForeignKey || "#{otherTable}_id"

                    intersectionCriterion = {}
                    intersectionCriterion[foreignKey] = _.pluck items, primaryKey
                    m = mohair.table(joinTable).where(intersectionCriterion)
                    sql = @postgresPlaceholders m.sql()
                    connection.query sql, m.params(), (err, results) ->
                        return cb err if err?
                        intersection = results.rows

                        criterion = {}
                        criterion[otherPrimaryKey] =
                            _.unique _.pluck intersection, otherForeignKey

                        chain = otherModel
                            .connection(connection)
                            .where(criterion)
                        if 'object' is typeof includes[includeName]
                            chain = chain.includes includes[includeName]

                        chain.find (err, associated) ->
                            return cb err if err?
                            items.forEach (item) ->
                                relevantIntersection = _.filter intersection, (x) ->
                                    x[foreignKey] is item[primaryKey]
                                otherPrimaryKeys = _.pluck relevantIntersection, otherForeignKey
                                item[includeName] = _.filter associated, (x) ->
                                    x[otherPrimaryKey] in otherPrimaryKeys
                            cb null, items
                else
                    throw new Error "unknown association type: #{assoc.type}"

        async.forEachSeries includeNames, fetchInclude, (err) ->
            return cb err if err?
            cb null, items

    # misc
    # ----

    postgresPlaceholders: (sql) ->
        # replace ? with $1, $2, ...
        index = 1
        sql.replace /\?/g, -> '$' + index++
