package main

import (
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

type Response struct {
	Status  string `json:"status"`
	Message string `json:"message"`
	Port    string `json:"port"`
	Time    string `json:"processed_at"`
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	r := gin.Default()
	r.Use(corsMiddleware())

	// Servir frontend estático (solo la réplica en 3001, o vía NGINX)
	r.Static("/static", "./static")
	r.StaticFile("/", "./static/index.html")

	// Endpoint de validación de transacciones
	r.GET("/validar", func(c *gin.Context) {
		rand.Seed(time.Now().UnixNano())
		approved := rand.Float32() < 0.80 // 80% aprobación

		status := "aprobada"
		msg := "Transacción aprobada correctamente."
		code := http.StatusOK

		if !approved {
			status = "rechazada"
			msg = "Transacción rechazada por política de riesgo."
			code = http.StatusUnprocessableEntity
		}

		c.JSON(code, Response{
			Status:  status,
			Message: msg,
			Port:    port,
			Time:    time.Now().Format(time.RFC3339),
		})
	})

	// Health check (útil para verificar réplicas individuales)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
			"port":   port,
			"time":   time.Now().Format(time.RFC3339),
		})
	})

	r.Run(":" + port)
}
