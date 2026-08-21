use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;

pub const DEFAULT_CHUNK_SIZE: usize = 64 * 1024; // 64 KB per chunk

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum TransferStatus {
    Initializing,
    Transferring,
    Paused,
    Verifying,
    Completed,
    Failed(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileMetadata {
    pub file_id: String,
    pub filename: String,
    pub total_bytes: u64,
    pub sha256_hash: String,
    pub chunk_size: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileChunk {
    pub file_id: String,
    pub sequence_number: u64,
    pub data: Vec<u8>,
}

pub struct ResumableFileTransfer {
    pub metadata: FileMetadata,
    pub confirmed_chunks: HashSet<u64>,
    pub status: TransferStatus,
    pub bytes_transferred: u64,
}

impl ResumableFileTransfer {
    pub fn new(metadata: FileMetadata) -> Self {
        Self {
            metadata,
            confirmed_chunks: HashSet::new(),
            status: TransferStatus::Initializing,
            bytes_transferred: 0,
        }
    }

    pub fn total_chunks(&self) -> u64 {
        (self.metadata.total_bytes + self.metadata.chunk_size as u64 - 1) / self.metadata.chunk_size as u64
    }

    pub fn get_next_chunk_offset(&self) -> u64 {
        let mut seq = 0;
        while self.confirmed_chunks.contains(&seq) {
            seq += 1;
        }
        seq
    }

    pub fn ack_chunk(&mut self, sequence_number: u64, chunk_len: usize) {
        if self.confirmed_chunks.insert(sequence_number) {
            self.bytes_transferred += chunk_len as u64;
        }
        if self.confirmed_chunks.len() as u64 >= self.total_chunks() {
            self.status = TransferStatus::Verifying;
        }
    }

    /// Verifies the completed file SHA-256 digest against metadata
    pub fn verify_file_sha256(&mut self, file_path: &Path) -> Result<bool, String> {
        let mut file = File::open(file_path).map_err(|e| e.to_string())?;
        let mut hasher = Sha256::new();
        let mut buffer = [0u8; 16384];

        loop {
            let count = file.read(&mut buffer).map_err(|e| e.to_string())?;
            if count == 0 {
                break;
            }
            hasher.update(&buffer[..count]);
        }

        let computed_hash = hex::encode(hasher.finalize());
        let matches = computed_hash.eq_ignore_ascii_case(&self.metadata.sha256_hash);
        if matches {
            self.status = TransferStatus::Completed;
        } else {
            self.status = TransferStatus::Failed("SHA-256 checksum mismatch".into());
        }
        Ok(matches)
    }

    /// Reads a chunk from disk without loading full file into memory
    pub fn read_chunk_from_file(
        file_path: &Path,
        sequence_number: u64,
        chunk_size: usize,
    ) -> Result<Vec<u8>, String> {
        let mut file = File::open(file_path).map_err(|e| e.to_string())?;
        let offset = sequence_number * chunk_size as u64;
        file.seek(SeekFrom::Start(offset)).map_err(|e| e.to_string())?;

        let mut buffer = vec![0u8; chunk_size];
        let bytes_read = file.read(&mut buffer).map_err(|e| e.to_string())?;
        buffer.truncate(bytes_read);
        Ok(buffer)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn test_chunk_resume_logic() {
        let meta = FileMetadata {
            file_id: "file1".into(),
            filename: "video.mp4".into(),
            total_bytes: 128 * 1024,
            sha256_hash: "dummy_hash".into(),
            chunk_size: DEFAULT_CHUNK_SIZE,
        };

        let mut transfer = ResumableFileTransfer::new(meta);
        assert_eq!(transfer.total_chunks(), 2);
        assert_eq!(transfer.get_next_chunk_offset(), 0);

        transfer.ack_chunk(0, DEFAULT_CHUNK_SIZE);
        assert_eq!(transfer.get_next_chunk_offset(), 1);
        assert_eq!(transfer.bytes_transferred, 64 * 1024);

        transfer.ack_chunk(1, DEFAULT_CHUNK_SIZE);
        assert_eq!(transfer.status, TransferStatus::Verifying);
    }

    #[test]
    fn test_file_integrity_verification() {
        let mut temp_file = NamedTempFile::new().unwrap();
        temp_file.write_all(b"Hello MeckChat File Transport!").unwrap();

        let mut hasher = Sha256::new();
        hasher.update(b"Hello MeckChat File Transport!");
        let expected_hash = hex::encode(hasher.finalize());

        let meta = FileMetadata {
            file_id: "file2".into(),
            filename: "test.txt".into(),
            total_bytes: 30,
            sha256_hash: expected_hash,
            chunk_size: DEFAULT_CHUNK_SIZE,
        };

        let mut transfer = ResumableFileTransfer::new(meta);
        let verified = transfer.verify_file_sha256(temp_file.path()).unwrap();
        assert!(verified);
        assert_eq!(transfer.status, TransferStatus::Completed);
    }
}
