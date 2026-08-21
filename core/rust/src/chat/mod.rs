use rusqlite::{params, Connection, Result as SqlResult};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MessageStatus {
    Pending,
    Sent,
    Delivered,
    Read,
    Failed,
}

impl MessageStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Pending => "PENDING",
            Self::Sent => "SENT",
            Self::Delivered => "DELIVERED",
            Self::Read => "READ",
            Self::Failed => "FAILED",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "SENT" => Self::Sent,
            "DELIVERED" => Self::Delivered,
            "READ" => Self::Read,
            "FAILED" => Self::Failed,
            _ => Self::Pending,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub message_id: String,
    pub sender_device_id: String,
    pub recipient_device_id: String,
    pub content: String,
    pub timestamp: u64,
    pub status: MessageStatus,
}

pub struct ChatDatabase {
    conn: Arc<Mutex<Connection>>,
}

impl ChatDatabase {
    pub fn new(db_path: &str) -> SqlResult<Self> {
        let conn = Connection::open(db_path)?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS chat_messages (
                message_id TEXT PRIMARY KEY,
                sender_device_id TEXT NOT NULL,
                recipient_device_id TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                status TEXT NOT NULL
            )",
            [],
        )?;
        Ok(Self {
            conn: Arc::new(Mutex::new(conn)),
        })
    }

    pub fn in_memory() -> SqlResult<Self> {
        Self::new(":memory:")
    }

    pub fn insert_message(&self, msg: &ChatMessage) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO chat_messages (message_id, sender_device_id, recipient_device_id, content, timestamp, status)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                msg.message_id,
                msg.sender_device_id,
                msg.recipient_device_id,
                msg.content,
                msg.timestamp,
                msg.status.as_str()
            ],
        )?;
        Ok(())
    }

    pub fn update_status(&self, message_id: &str, status: MessageStatus) -> SqlResult<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE chat_messages SET status = ?1 WHERE message_id = ?2",
            params![status.as_str(), message_id],
        )?;
        Ok(())
    }

    pub fn get_conversation(&self, peer_device_id: &str) -> SqlResult<Vec<ChatMessage>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT message_id, sender_device_id, recipient_device_id, content, timestamp, status
             FROM chat_messages
             WHERE sender_device_id = ?1 OR recipient_device_id = ?1
             ORDER BY timestamp ASC",
        )?;

        let msgs = stmt
            .query_map(params![peer_device_id], |row| {
                let status_str: String = row.get(5)?;
                Ok(ChatMessage {
                    message_id: row.get(0)?,
                    sender_device_id: row.get(1)?,
                    recipient_device_id: row.get(2)?,
                    content: row.get(3)?,
                    timestamp: row.get(4)?,
                    status: MessageStatus::from_str(&status_str),
                })
            })?
            .filter_map(|r| r.ok())
            .collect();

        Ok(msgs)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_chat_sqlite_storage() {
        let db = ChatDatabase::in_memory().unwrap();
        let msg = ChatMessage {
            message_id: "msg1".into(),
            sender_device_id: "devA".into(),
            recipient_device_id: "devB".into(),
            content: "Hello over WireGuard!".into(),
            timestamp: 1724242920,
            status: MessageStatus::Sent,
        };

        db.insert_message(&msg).unwrap();
        let history = db.get_conversation("devB").unwrap();
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].content, "Hello over WireGuard!");

        db.update_status("msg1", MessageStatus::Read).unwrap();
        let updated = db.get_conversation("devB").unwrap();
        assert_eq!(updated[0].status, MessageStatus::Read);
    }
}
