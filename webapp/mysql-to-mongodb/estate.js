const Sequelize = require('sequelize');
module.exports = function(sequelize, DataTypes) {
  return sequelize.define('estate', {
    id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      primaryKey: true
    },
    name: {
      type: DataTypes.STRING(64),
      allowNull: false
    },
    description: {
      type: DataTypes.STRING(4096),
      allowNull: false
    },
    thumbnail: {
      type: DataTypes.STRING(128),
      allowNull: false
    },
    address: {
      type: DataTypes.STRING(128),
      allowNull: false
    },
    latitude: {
      type: DataTypes.DOUBLE,
      allowNull: false
    },
    longitude: {
      type: DataTypes.DOUBLE,
      allowNull: false
    },
    rent: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    door_height: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    door_width: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    features: {
      type: DataTypes.STRING(64),
      allowNull: false
    },
    popularity: {
      type: DataTypes.INTEGER,
      allowNull: false
    }
  }, {
    sequelize,
    tableName: 'estate',
    timestamps: false,
    indexes: [
      {
        name: "PRIMARY",
        unique: true,
        using: "BTREE",
        fields: [
          { name: "id" },
        ]
      },
    ]
  });
};
