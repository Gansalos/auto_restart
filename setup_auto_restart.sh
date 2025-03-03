#!/bin/bash

# Убеждаемся, что скрипт запускается с правами root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт от имени root (sudo)"
  exit 1
fi

# Устанавливаем nano, если его нет
echo "Установка nano (если не установлен)..."
apt-get update && apt-get install -y nano

# 1. Создаем скрипт автоперезапуска
echo "Создаем файл /root/auto_restart.sh..."
cat << 'EOF' > /root/auto_restart.sh
#!/bin/bash

while true; do
    # Ищем контейнеры в статусе "exited"
    stopped_containers=$(docker ps -aq --filter "status=exited")

    # Если есть остановленные контейнеры, перезапускаем их
    if [ -n "$stopped_containers" ]; then
        echo "Найдены остановленные контейнеры. Перезапуск..."
        docker start $stopped_containers
    fi

    # Пауза между проверками (5 минут)
    sleep 300
done
EOF

# 2. Делаем скрипт исполняемым
echo "Делаем скрипт исполняемым..."
chmod +x /root/auto_restart.sh

# 3. Создаем systemd-сервис
echo "Создаем файл сервиса /etc/systemd/system/auto_restart.service..."
cat << 'EOF' > /etc/systemd/system/auto_restart.service
[Unit]
Description=Auto Restart Docker Containers
After=docker.service

[Service]
ExecStart=/root/auto_restart.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 4. Перезагружаем systemd и запускаем сервис
echo "Перезагружаем systemd и запускаем сервис..."
systemctl daemon-reload
systemctl enable auto_restart.service
systemctl start auto_restart.service

# 5. Проверяем статус сервиса
echo "Проверка статуса сервиса..."
systemctl status auto_restart.service

echo "Настройка завершена!"
