CREATE TABLE IF NOT EXISTS users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  price DECIMAL(10,2) DEFAULT 0,
  stock INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reviews (
  id INT PRIMARY KEY AUTO_INCREMENT,
  product_id INT NOT NULL,
  user_id INT NOT NULL,
  rating INT NOT NULL,
  comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY unique_review (product_id, user_id),
  CONSTRAINT chk_rating CHECK (rating >= 1 AND rating <= 5)
);

-- Insérer données de test
INSERT INTO users (email, name) VALUES 
('user1@test.com', 'User One'),
('user2@test.com', 'User Two'),
('admin@test.com', 'Admin User');

INSERT INTO products (name, price, stock) VALUES 
('iPhone 15 Pro', 1199.99, 50),
('Samsung Galaxy S24', 1099.99, 44),
('MacBook Pro M3', 2499.99, 30);

INSERT INTO reviews (product_id, user_id, rating, comment) VALUES 
(1, 1, 5, 'Excellent smartphone! La caméra est incroyable.'),
(1, 2, 4, 'Très bon produit mais un peu cher.'),
(2, 1, 5, 'Meilleur Android sur le marché!'),
(3, 2, 5, 'Performance exceptionnelle pour le dev.');