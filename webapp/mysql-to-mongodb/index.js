const { Sequelize } = require('sequelize');
const fs = require('fs');
const path = require('path');
const sequelize = new Sequelize('isuumo', 'isucon', 'isucon', {
  host: '127.0.0.1',
  dialect: 'mysql' /* one of 'mysql' | 'mariadb' | 'postgres' | 'mssql' */
})
sequelize.authenticate().then(() => {
  console.log('Connection has been established successfully.');
  }).catch ((error) => {
    console.error('Unable to connect to the database:', error);
  })
var initModelsEstate = require("./init-models-estate");
var modelsEstate = initModelsEstate(sequelize);
modelsEstate.estate.findAll({}).then((estates) => {
  estates.forEach(element => {
    element.dataValues.coor = [element.dataValues.latitude, element.dataValues.longitude]
    delete element.dataValues.latitude
    delete element.dataValues.longitude
  });
  fs.writeFileSync(path.resolve(__dirname, '../mongo/estate.json'), JSON.stringify(estates, null, 2));
  console.log('donewriting')
}).catch ((error) => {
  console.error('error fetching data', error)
})

var initModelsChair = require("./init-models-chair");
var modelsChair = initModelsChair(sequelize);
modelsChair.chair.findAll({}).then((chairs) => {
  fs.writeFileSync(path.resolve(__dirname, '../mongo/chair.json'), JSON.stringify(chairs, null, 2));
  console.log('donewriting')
}).catch ((error) => {
  console.error('error fetching data', error)
})
