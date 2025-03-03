#!/bin/bash

# Убеждаемся, что скрипт запускается с правами root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт от имени root (sudo)"
  exit 1
fi

# Устанавливаем curl, если его нет (для будущих улучшений, сейчас не используется)
echo "Установка curl (если не установлен)..."
apt-get update && apt-get install -y curl

# Создаём скрипт мониторинга прямо в /root/vana_monitor.sh
echo "Создаём скрипт мониторинга /root/vana_monitor.sh..."
cat << 'EOF' > /root/vana_monitor.sh
#!/bin/bash

# Интервал проверки в секундах (5 минут)
CHECK_INTERVAL=300

# Ключевые слова для поиска ошибок
ERROR_PATTERNS=("ERROR" "RuntimeError" "Traceback" "exception")

while true; do
    echo "Проверка логов vana.service на ошибки..."

    # Получаем последние 50 строк логов за последние 5 минут
    LOGS=$(journalctl -u vana.service --since "5 minutes ago" -n 50)

    # Флаг для отслеживания ошибок
    ERROR_FOUND=false

    # Проверяем логи на наличие ошибок
    for PATTERN in "${ERROR_PATTERNS[@]}"; do
        if echo "$LOGS" | grep -i "$PATTERN" > /dev/null; then
            echo "Найдена ошибка: $PATTERN"
            ERROR_FOUND=true
            break
        fi
    done

    # Если ошибка найдена, перезапускаем службу
    if [ "$ERROR_FOUND" = true ]; then
        echo "Обнаружены ошибки в логах. Перезапуск vana.service..."
        systemctl restart vana.service
        if [ $? -eq 0 ]; then
            echo "Служба успешно перезапущена. Ждём 30 секунд перед следующей проверкой..."
            sleep 30  # Даём время службе запуститься
        else
            echo "Ошибка при перезапуске службы!"
        fi
    else
        echo "Ошибок не найдено. Всё работает нормально."
    fi

    # Ждём до следующей проверки
    echo "Следующая проверка через $CHECK_INTERVAL секунд..."
    sleep $CHECK_INTERVAL
done
EOF

# Делаем скрипт исполняемым
echo "Делаем скрипт исполняемым..."
chmod +x /root/vana_monitor.sh

# Создаем systemd-сервис
echo "Создаем файл сервиса /etc/systemd/system/vana_monitor.service..."
cat << 'EOF' > /etc/systemd/system/vana_monitor.service
[Unit]
Description=Vana Service Monitor and Restart
After=network.target vana.service

[Service]
ExecStart=/root/vana_monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Перезагружаем systemd и запускаем сервис
echo "Настраиваем и запускаем сервис..."
systemctl daemon-reload
systemctl enable vana_monitor.service
systemctl start vana_monitor.service

# Проверяем статус сервиса
echo "Проверка статуса сервиса..."
systemctl status vana_monitor.service

echo "Установка завершена! Скрипт будет запускаться после каждой перезагрузки."
