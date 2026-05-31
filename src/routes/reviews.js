import express from 'express';
import { getConnection } from '../config/database.js';
import { authMiddleware } from '../middleware/authMiddleware.js';

const router = express.Router();

// GET /product/:id - Avis d'un produit (public)
router.get('/product/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const connection = await getConnection();
    
    const [reviews] = await connection.query(
      `SELECT r.*, u.name as user_name 
       FROM reviews r 
       JOIN users u ON r.user_id = u.id 
       WHERE r.product_id = ? 
       ORDER BY r.created_at DESC`,
      [id]
    );
    
    connection.release();
    res.json(reviews);
  } catch (error) {
    console.error('Error fetching reviews:', error);
    res.status(500).json({ error: 'Failed to fetch reviews' });
  }
});

// POST / - Créer un avis (authentifié)
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { product_id, rating, comment } = req.body;
    const userId = req.user.userId;
    
    if (!product_id || !rating) {
      return res.status(400).json({ error: 'Product ID and rating are required' });
    }
    
    if (rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5' });
    }
    
    const connection = await getConnection();
    
    // Vérifier que le produit existe
    const [products] = await connection.query(
      'SELECT id FROM products WHERE id = ?',
      [product_id]
    );
    
    if (products.length === 0) {
      connection.release();
      return res.status(404).json({ error: 'Product not found' });
    }
    
    // Vérifier si l'utilisateur a déjà fait un avis sur ce produit
    const [existing] = await connection.query(
      'SELECT id FROM reviews WHERE product_id = ? AND user_id = ?',
      [product_id, userId]
    );
    
    if (existing.length > 0) {
      connection.release();
      return res.status(400).json({ error: 'You have already reviewed this product' });
    }
    
    const [result] = await connection.query(
      'INSERT INTO reviews (product_id, user_id, rating, comment) VALUES (?, ?, ?, ?)',
      [product_id, userId, rating, comment || '']
    );
    
    const [newReview] = await connection.query(
      `SELECT r.*, u.name as user_name 
       FROM reviews r 
       JOIN users u ON r.user_id = u.id 
       WHERE r.id = ?`,
      [result.insertId]
    );
    
    connection.release();
    res.status(201).json(newReview[0]);
  } catch (error) {
    console.error('Error creating review:', error);
    res.status(500).json({ error: 'Failed to create review' });
  }
});

// PUT /:id - Modifier un avis (authentifié)
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, comment } = req.body;
    const userId = req.user.userId;
    
    if (rating && (rating < 1 || rating > 5)) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5' });
    }
    
    const connection = await getConnection();
    
    // Vérifier que l'avis existe et appartient à l'utilisateur
    const [reviews] = await connection.query(
      'SELECT user_id FROM reviews WHERE id = ?',
      [id]
    );
    
    if (reviews.length === 0) {
      connection.release();
      return res.status(404).json({ error: 'Review not found' });
    }
    
    if (reviews[0].user_id !== userId) {
      connection.release();
      return res.status(403).json({ error: 'You can only edit your own reviews' });
    }
    
    await connection.query(
      'UPDATE reviews SET rating = ?, comment = ? WHERE id = ?',
      [rating, comment, id]
    );
    
    connection.release();
    res.json({ message: 'Review updated successfully' });
  } catch (error) {
    console.error('Error updating review:', error);
    res.status(500).json({ error: 'Failed to update review' });
  }
});

// DELETE /:id - Supprimer un avis (authentifié)
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.userId;
    
    const connection = await getConnection();
    
    // Vérifier que l'avis existe et appartient à l'utilisateur
    const [reviews] = await connection.query(
      'SELECT user_id FROM reviews WHERE id = ?',
      [id]
    );
    
    if (reviews.length === 0) {
      connection.release();
      return res.status(404).json({ error: 'Review not found' });
    }
    
    if (reviews[0].user_id !== userId) {
      connection.release();
      return res.status(403).json({ error: 'You can only delete your own reviews' });
    }
    
    await connection.query('DELETE FROM reviews WHERE id = ?', [id]);
    
    connection.release();
    res.json({ message: 'Review deleted successfully' });
  } catch (error) {
    console.error('Error deleting review:', error);
    res.status(500).json({ error: 'Failed to delete review' });
  }
});

export default router;
