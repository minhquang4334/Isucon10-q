DROP DATABASE IF EXISTS isuumo;
CREATE DATABASE isuumo COLLATE utf8mb4_general_ci;

DROP TABLE IF EXISTS isuumo.estate;
DROP TABLE IF EXISTS isuumo.chair;
DROP TABLE IF EXISTS isuumo.estate_features;
DROP TABLE IF EXISTS isuumo.chair_features;

CREATE TABLE isuumo.estate
(
    id          INTEGER             NOT NULL,
    name        VARCHAR(64)         NOT NULL,
    description VARCHAR(4096)       NOT NULL,
    thumbnail   VARCHAR(128)        NOT NULL,
    address     VARCHAR(128)        NOT NULL,
    latitude    DOUBLE PRECISION    NOT NULL,
    longitude   DOUBLE PRECISION    NOT NULL,
    rent        INTEGER             NOT NULL,
    door_height INTEGER             NOT NULL,
    door_width  INTEGER             NOT NULL,
    features    VARCHAR(64)         NOT NULL,
    popularity  INTEGER             NOT NULL,
    PRIMARY KEY (id, rent),
    point       geometry GENERATED ALWAYS AS
        (POINT(latitude, longitude)) STORED NOT NULL,
    INDEX idx_rent_id (rent ASC, id ASC),
    INDEX idx_popularity (popularity DESC, id ASC),
    SPATIAL INDEX(point)
);
#PARTITION BY RANGE(rent)  (
#    PARTITION rent_0 VALUES LESS THAN (50000),
#    PARTITION rent_1 VALUES LESS THAN (100000),
#    PARTITION rent_2 VALUES LESS THAN (150000),
#    PARTITION rent_3 VALUES LESS THAN MAXVALUE
#);

CREATE TABLE isuumo.chair
(
    id          INTEGER         NOT NULL,
    name        VARCHAR(64)     NOT NULL,
    description VARCHAR(4096)   NOT NULL,
    thumbnail   VARCHAR(128)    NOT NULL,
    price       INTEGER         NOT NULL,
    height      INTEGER         NOT NULL,
    width       INTEGER         NOT NULL,
    depth       INTEGER         NOT NULL,
    color       VARCHAR(64)     NOT NULL,
    features    VARCHAR(64)     NOT NULL,
    kind        VARCHAR(64)     NOT NULL,
    popularity  INTEGER         NOT NULL,
    stock       INTEGER         NOT NULL,

    PRIMARY KEY (id, price),
    INDEX idx_price_id (price ASC, id ASC),

    -- 不要
    -- INDEX idx_depth (depth),

    -- https://github.com/soudai/isucon10-qualify/blob/1be06d2540eb94244596e9a7b541f7c4caf4c14f/webapp/ruby/app.rb#L175-L183
    --
    -- INDEX idx_color (color),
    -- INDEX idx_kind (kind),
    --
    -- INDEX idx_color_popularity (color, popularity DESC),
    -- INDEX idx_kind_popularity (kind, popularity DESC)
	
    INDEX idx_popularity_id (popularity DESC, id ASC)
    -- 常に他の検索条件との複合で必要なので単体では不要
    -- INDEX idx_popularity (popularity),

    -- 不要
    -- INDEX idx_stock_price (stock, price),
    -- INDEX idx_height_width (height, width),
    -- INDEX idx_width_height (width, height)
)
PARTITION BY RANGE(price)  (
    PARTITION price_0 VALUES LESS THAN (3000),
    PARTITION price_1 VALUES LESS THAN (6000),
    PARTITION price_2 VALUES LESS THAN (9000),
    PARTITION price_3 VALUES LESS THAN (12000),
    PARTITION price_4 VALUES LESS THAN (15000),
    PARTITION price_5 VALUES LESS THAN MAXVALUE
);
