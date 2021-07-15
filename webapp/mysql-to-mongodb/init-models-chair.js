var DataTypes = require("sequelize").DataTypes;
var _chair = require("./chair");

function initModelsChair(sequelize) {
  var chair = _chair(sequelize, DataTypes);


  return {
    chair,
  };
}
module.exports = initModelsChair;
module.exports.initModelsChair = initModelsChair;
module.exports.default = initModelsChair;
