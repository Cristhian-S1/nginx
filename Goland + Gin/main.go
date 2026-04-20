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

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	r := gin.Default()

	r.GET("/validar", func(c *gin.Context) {
		rand.Seed(time.Now().UnixNano())
		approved := rand.Float32() < 0.80 // 80% éxito, 20% rechazo

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

	r.Run(":" + port)
}
