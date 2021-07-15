var DataTypes = require("sequelize").DataTypes;
var _estate = require("./estate");

function initModelsEstate(sequelize) {
  var estate = _estate(sequelize, DataTypes);


  return {
    estate,
  };
}
module.exports = initModelsEstate;
module.exports.initModelsEstate = initModelsEstate;
module.exports.default = initModelsEstate;
