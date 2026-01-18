#!/bin/bash

# Backup and Restore Script for Railway Deployment
# Handles database backups and restoration procedures

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/../../../backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

show_help() {
    cat << EOF
Backup and Restore Script for Railway Deployment

Usage: $0 <command> [options]

Commands:
    backup              Create backups of all services
    restore <timestamp> Restore from a specific backup
    list                List available backups
    verify <timestamp>  Verify backup integrity
    cleanup             Remove backups older than 30 days

Options:
    --postgres-only     Only backup/restore PostgreSQL
    --qdrant-only       Only backup/restore Qdrant
    --help              Show this help message

Examples:
    $0 backup
    $0 restore 20260118_143000
    $0 verify 20260118_143000
    $0 list
    $0 cleanup

EOF
}

# Backup PostgreSQL
backup_postgres() {
    echo -e "${BLUE}Backing up PostgreSQL...${NC}"

    DATABASE_URL=$(railway variables --service postgres-pgvector 2>/dev/null | grep "DATABASE_URL=" | cut -d'=' -f2- || echo "")

    if [ -z "$DATABASE_URL" ]; then
        echo -e "${RED}✗ DATABASE_URL not found${NC}"
        return 1
    fi

    backup_file="$BACKUP_DIR/postgres_${TIMESTAMP}.dump"

    echo -n "  Creating database dump... "
    if railway run --service r2r -- pg_dump -Fc "$DATABASE_URL" > "$backup_file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"

        # Verify backup
        echo -n "  Verifying backup integrity... "
        if pg_restore --list "$backup_file" &>/dev/null; then
            echo -e "${GREEN}✓${NC}"

            # Get backup size
            size=$(du -h "$backup_file" | cut -f1)
            echo -e "  Backup size: $size"
            echo -e "  Location: $backup_file"

            # Create metadata file
            cat > "$BACKUP_DIR/postgres_${TIMESTAMP}.meta" << EOF
backup_type=postgres
timestamp=$TIMESTAMP
date=$(date)
size=$size
database_url_hash=$(echo "$DATABASE_URL" | md5sum | cut -d' ' -f1)
EOF
            return 0
        else
            echo -e "${RED}✗ Backup verification failed${NC}"
            rm -f "$backup_file"
            return 1
        fi
    else
        echo -e "${RED}✗ Backup failed${NC}"
        return 1
    fi
}

# Restore PostgreSQL
restore_postgres() {
    local timestamp=$1
    backup_file="$BACKUP_DIR/postgres_${timestamp}.dump"

    echo -e "${BLUE}Restoring PostgreSQL from backup...${NC}"

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}✗ Backup file not found: $backup_file${NC}"
        return 1
    fi

    echo -e "${YELLOW}WARNING: This will restore the database to the backup state.${NC}"
    echo -e "${YELLOW}Any data created after the backup will be lost.${NC}"
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Restore cancelled."
        return 1
    fi

    DATABASE_URL=$(railway variables --service postgres-pgvector 2>/dev/null | grep "DATABASE_URL=" | cut -d'=' -f2- || echo "")

    echo -n "  Restoring database... "
    if railway run --service r2r -- pg_restore -d "$DATABASE_URL" --clean --if-exists < "$backup_file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        echo -e "${GREEN}Database restored successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Restore failed${NC}"
        return 1
    fi
}

# Backup Qdrant
backup_qdrant() {
    echo -e "${BLUE}Backing up Qdrant collections...${NC}"

    QDRANT_URL=$(railway variables --service r2r 2>/dev/null | grep "QDRANT_URL=" | cut -d'=' -f2- || echo "")
    QDRANT_API_KEY=$(railway variables --service qdrant 2>/dev/null | grep "QDRANT_API_KEY=" | cut -d'=' -f2- || echo "")

    if [ -z "$QDRANT_URL" ] || [ -z "$QDRANT_API_KEY" ]; then
        echo -e "${RED}✗ Qdrant not configured${NC}"
        return 1
    fi

    # Get list of collections
    collections=$(curl -s -H "api-key: $QDRANT_API_KEY" "$QDRANT_URL/collections" 2>/dev/null | \
        grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "")

    if [ -z "$collections" ]; then
        echo -e "${YELLOW}⚠ No collections found${NC}"
        return 0
    fi

    backup_dir="$BACKUP_DIR/qdrant_${TIMESTAMP}"
    mkdir -p "$backup_dir"

    collection_count=0
    for collection in $collections; do
        echo -n "  Creating snapshot for $collection... "

        # Create snapshot
        snapshot_result=$(curl -s -X POST -H "api-key: $QDRANT_API_KEY" \
            "$QDRANT_URL/collections/$collection/snapshots" 2>/dev/null || echo "")

        snapshot_name=$(echo "$snapshot_result" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "")

        if [ -n "$snapshot_name" ]; then
            # Download snapshot
            if curl -s -H "api-key: $QDRANT_API_KEY" \
                "$QDRANT_URL/collections/$collection/snapshots/$snapshot_name" \
                -o "$backup_dir/${collection}.snapshot" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((collection_count++))
            else
                echo -e "${RED}✗${NC}"
            fi
        else
            echo -e "${RED}✗ Snapshot creation failed${NC}"
        fi
    done

    if [ $collection_count -gt 0 ]; then
        echo -e "  Backed up $collection_count collection(s)"
        echo -e "  Location: $backup_dir"

        # Create metadata
        cat > "$backup_dir/metadata.txt" << EOF
backup_type=qdrant
timestamp=$TIMESTAMP
date=$(date)
collections=$collection_count
EOF
        return 0
    else
        echo -e "${RED}✗ No collections backed up${NC}"
        rm -rf "$backup_dir"
        return 1
    fi
}

# Restore Qdrant
restore_qdrant() {
    local timestamp=$1
    backup_dir="$BACKUP_DIR/qdrant_${timestamp}"

    echo -e "${BLUE}Restoring Qdrant from backup...${NC}"

    if [ ! -d "$backup_dir" ]; then
        echo -e "${RED}✗ Backup directory not found: $backup_dir${NC}"
        return 1
    fi

    QDRANT_URL=$(railway variables --service r2r 2>/dev/null | grep "QDRANT_URL=" | cut -d'=' -f2- || echo "")
    QDRANT_API_KEY=$(railway variables --service qdrant 2>/dev/null | grep "QDRANT_API_KEY=" | cut -d'=' -f2- || echo "")

    echo -e "${YELLOW}WARNING: This will restore Qdrant collections to the backup state.${NC}"
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Restore cancelled."
        return 1
    fi

    restored_count=0
    for snapshot_file in "$backup_dir"/*.snapshot; do
        if [ -f "$snapshot_file" ]; then
            collection=$(basename "$snapshot_file" .snapshot)
            echo -n "  Restoring $collection... "

            # Upload and restore snapshot
            if curl -s -X PUT -H "api-key: $QDRANT_API_KEY" \
                -F "snapshot=@$snapshot_file" \
                "$QDRANT_URL/collections/$collection/snapshots/recover" 2>/dev/null | grep -q "true\|ok"; then
                echo -e "${GREEN}✓${NC}"
                ((restored_count++))
            else
                echo -e "${RED}✗${NC}"
            fi
        fi
    done

    if [ $restored_count -gt 0 ]; then
        echo -e "${GREEN}Restored $restored_count collection(s)${NC}"
        return 0
    else
        echo -e "${RED}✗ No collections restored${NC}"
        return 1
    fi
}

# List backups
list_backups() {
    echo -e "${BLUE}Available Backups:${NC}"
    echo ""

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo "No backups found."
        return 0
    fi

    # List PostgreSQL backups
    echo "PostgreSQL Backups:"
    for meta_file in "$BACKUP_DIR"/postgres_*.meta; do
        if [ -f "$meta_file" ]; then
            timestamp=$(grep "timestamp=" "$meta_file" | cut -d'=' -f2)
            date=$(grep "date=" "$meta_file" | cut -d'=' -f2-)
            size=$(grep "size=" "$meta_file" | cut -d'=' -f2)
            dump_file="${meta_file%.meta}.dump"

            if [ -f "$dump_file" ]; then
                echo "  [$timestamp] $date - $size"
            fi
        fi
    done

    # List Qdrant backups
    echo ""
    echo "Qdrant Backups:"
    for backup_dir in "$BACKUP_DIR"/qdrant_*/; do
        if [ -d "$backup_dir" ]; then
            meta_file="$backup_dir/metadata.txt"
            if [ -f "$meta_file" ]; then
                timestamp=$(grep "timestamp=" "$meta_file" | cut -d'=' -f2)
                date=$(grep "date=" "$meta_file" | cut -d'=' -f2-)
                collections=$(grep "collections=" "$meta_file" | cut -d'=' -f2)
                echo "  [$timestamp] $date - $collections collection(s)"
            fi
        fi
    done
    echo ""
}

# Verify backup
verify_backup() {
    local timestamp=$1

    echo -e "${BLUE}Verifying Backup: $timestamp${NC}"
    echo ""

    # Check PostgreSQL backup
    postgres_dump="$BACKUP_DIR/postgres_${timestamp}.dump"
    if [ -f "$postgres_dump" ]; then
        echo -n "PostgreSQL backup... "
        if pg_restore --list "$postgres_dump" &>/dev/null; then
            echo -e "${GREEN}✓ Valid${NC}"
        else
            echo -e "${RED}✗ Invalid${NC}"
        fi
    else
        echo "PostgreSQL backup... Not found"
    fi

    # Check Qdrant backup
    qdrant_dir="$BACKUP_DIR/qdrant_${timestamp}"
    if [ -d "$qdrant_dir" ]; then
        snapshot_count=$(find "$qdrant_dir" -name "*.snapshot" | wc -l)
        echo "Qdrant backup... Found $snapshot_count snapshot(s)"
    else
        echo "Qdrant backup... Not found"
    fi
    echo ""
}

# Cleanup old backups
cleanup_backups() {
    echo -e "${BLUE}Cleaning up old backups...${NC}"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "No backup directory found."
        return 0
    fi

    # Delete files older than 30 days
    deleted=0

    # PostgreSQL backups
    find "$BACKUP_DIR" -name "postgres_*.dump" -mtime +30 -exec rm -f {} \; -exec echo "Deleted {}" \; | wc -l | xargs echo "Deleted PostgreSQL backups:"
    find "$BACKUP_DIR" -name "postgres_*.meta" -mtime +30 -exec rm -f {} \;

    # Qdrant backups
    find "$BACKUP_DIR" -type d -name "qdrant_*" -mtime +30 -exec rm -rf {} \; -exec echo "Deleted {}" \; | wc -l | xargs echo "Deleted Qdrant backups:"

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main command handler
main() {
    command=$1
    shift || true

    case "$command" in
        backup)
            echo "=================================================="
            echo "  Creating Backups - $TIMESTAMP"
            echo "=================================================="
            echo ""

            if [[ "$*" == *"--postgres-only"* ]]; then
                backup_postgres
            elif [[ "$*" == *"--qdrant-only"* ]]; then
                backup_qdrant
            else
                backup_postgres
                echo ""
                backup_qdrant
            fi

            echo ""
            echo -e "${GREEN}✓ Backup process completed${NC}"
            ;;

        restore)
            timestamp=$1
            if [ -z "$timestamp" ]; then
                echo -e "${RED}Error: Timestamp required${NC}"
                echo "Usage: $0 restore <timestamp>"
                exit 1
            fi

            echo "=================================================="
            echo "  Restoring from Backup - $timestamp"
            echo "=================================================="
            echo ""

            if [[ "$*" == *"--postgres-only"* ]]; then
                restore_postgres "$timestamp"
            elif [[ "$*" == *"--qdrant-only"* ]]; then
                restore_qdrant "$timestamp"
            else
                restore_postgres "$timestamp"
                echo ""
                restore_qdrant "$timestamp"
            fi
            ;;

        list)
            list_backups
            ;;

        verify)
            timestamp=$1
            if [ -z "$timestamp" ]; then
                echo -e "${RED}Error: Timestamp required${NC}"
                echo "Usage: $0 verify <timestamp>"
                exit 1
            fi
            verify_backup "$timestamp"
            ;;

        cleanup)
            cleanup_backups
            ;;

        --help|-h|help)
            show_help
            ;;

        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
