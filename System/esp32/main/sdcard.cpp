#include "sdcard.h"
#include <sys/unistd.h>
#include <sys/stat.h>
#include <esp_vfs_fat.h>
#include <sdmmc_cmd.h>
#include <dirent.h>
#include <errno.h>
#include "led.h"

static const char *TAG = "sdcard";

#if CONFIG_IDF_TARGET_ESP32S2
#    define SPI_DMA_CHAN host.slot
#else
#    define SPI_DMA_CHAN SPI_DMA_CH_AUTO
#endif

#define MAX_FDS (10)

struct state {
    FILE *fds[MAX_FDS];
};

static struct state state;

SDCardVFS::SDCardVFS() {
}

SDCardVFS &SDCardVFS::instance() {
    static SDCardVFS vfs;
    return vfs;
}

void SDCardVFS::init(void) {
    ESP_LOGI(TAG, "Initializing SD card");

    esp_err_t        ret;
    sdmmc_host_t     host    = SDSPI_HOST_DEFAULT();
    spi_bus_config_t bus_cfg = {
        .mosi_io_num     = (gpio_num_t)IOPIN_SD_MOSI,
        .miso_io_num     = (gpio_num_t)IOPIN_SD_MISO,
        .sclk_io_num     = (gpio_num_t)IOPIN_SD_SCK,
        .quadwp_io_num   = -1,
        .quadhd_io_num   = -1,
        .max_transfer_sz = 4000,
    };
    ret = spi_bus_initialize((spi_host_device_t)host.slot, &bus_cfg, SPI_DMA_CHAN);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize bus.");
        return;
    }

    const char *mount_point = MOUNT_POINT;

    sdspi_device_config_t slot_config = SDSPI_DEVICE_CONFIG_DEFAULT();
    slot_config.gpio_cs               = (gpio_num_t)IOPIN_SD_SSEL_N;
    slot_config.gpio_cd               = (gpio_num_t)IOPIN_SD_CD_N;
    slot_config.gpio_wp               = (gpio_num_t)IOPIN_SD_WP_N;
    slot_config.host_id               = (spi_host_device_t)host.slot;

    ESP_LOGI(TAG, "Mounting filesystem");

    sdmmc_card_t                    *card;
    esp_vfs_fat_sdmmc_mount_config_t mount_config = {
        .max_files = 5,
    };
    ret = esp_vfs_fat_sdspi_mount(mount_point, &host, &slot_config, &mount_config, &card);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to mount card: %s", esp_err_to_name(ret));
        return;
    }

    ESP_LOGI(TAG, "Filesystem mounted");

    // Card has been initialized, print its properties
    sdmmc_card_print_info(stdout, card);
}

static char *get_fullpath(const char *path) {
    // Compose full path
    char *full_path = (char *)malloc(strlen(MOUNT_POINT) + 1 + strlen(path) + 1);
    assert(full_path != NULL);
    strcpy(full_path, MOUNT_POINT);
    strcat(full_path, "/");
    strcat(full_path, path);
    return full_path;
}

int SDCardVFS::open(uint8_t flags, const char *path) {
    // Translate flags
    int  mi = 0;
    char mode[5];

    // if (flags & FO_CREATE)
    //     oflag |= O_CREAT;

    switch (flags & FO_ACCMODE) {
        case FO_RDONLY:
            mode[mi++] = 'r';
            break;
        case FO_WRONLY:
            if (flags & FO_APPEND) {
                mode[mi++] = 'a';
            } else {
                mode[mi++] = 'w';
            }
            if (flags & FO_EXCL) {
                mode[mi++] = 'x';
            }

            break;
        case FO_RDWR:
            if (flags & FO_APPEND) {
                mode[mi++] = 'a';
                mode[mi++] = '+';
            } else if (flags & FO_TRUNC) {
                mode[mi++] = 'w';
                mode[mi++] = '+';
            } else {
                mode[mi++] = 'r';
                mode[mi++] = '+';
            }
            if (flags & FO_EXCL) {
                mode[mi++] = 'x';
            }
            break;

        default: {
            // Error
            return ERR_PARAM;
        }
    }
    mode[mi++] = 'b';
    mode[mi]   = 0;

    // Find free file descriptor
    int fd = -1;
    for (int i = 0; i < MAX_FDS; i++) {
        if (state.fds[i] == NULL) {
            fd = i;
            break;
        }
    }
    if (fd == -1)
        return ERR_TOO_MANY_OPEN;

    char *full_path = get_fullpath(path);
    led_flash_start();
    FILE *f = fopen(full_path, mode);
    led_flash_stop();
    int err_no = errno;
    free(full_path);

    if (f == NULL) {
        uint8_t err = ERR_NOT_FOUND;
        switch (err_no) {
            case EACCES: err = ERR_NOT_FOUND; break;
            case EEXIST: err = ERR_EXISTS; break;
            default: err = ERR_NOT_FOUND; break;
        }
        return err;
    }
    state.fds[fd] = f;
    return fd;
}

int SDCardVFS::close(int fd) {
    if (fd >= MAX_FDS || state.fds[fd] == NULL)
        return ERR_PARAM;
    FILE *f = state.fds[fd];

    fclose(f);
    state.fds[fd] = NULL;
    return 0;
}

int SDCardVFS::read(int fd, uint16_t size, void *buf) {
    if (fd >= MAX_FDS || state.fds[fd] == NULL)
        return ERR_PARAM;
    FILE *f = state.fds[fd];

    // Use RX buffer as temporary storage
    led_flash_start();
    int result = (int)fread(buf, 1, size, f);
    led_flash_stop();
    return (result < 0) ? ERR_OTHER : result;
}

int SDCardVFS::write(int fd, uint16_t size, const void *buf) {
    if (fd >= MAX_FDS || state.fds[fd] == NULL)
        return ERR_PARAM;
    FILE *f = state.fds[fd];

    led_flash_start();
    int result = (int)fwrite(buf, 1, size, f);
    led_flash_stop();
    return (result < 0) ? ERR_OTHER : result;
}

int SDCardVFS::seek(int fd, uint32_t offset) {
    if (fd >= MAX_FDS || state.fds[fd] == NULL)
        return ERR_PARAM;
    FILE *f = state.fds[fd];

    led_flash_start();
    int result = fseek(f, offset, SEEK_SET);
    led_flash_stop();
    return (result < 0) ? ERR_OTHER : 0;
}

int SDCardVFS::tell(int fd) {
    if (fd >= MAX_FDS || state.fds[fd] == NULL)
        return ERR_PARAM;
    FILE *f = state.fds[fd];

    led_flash_start();
    int result = ftell(f);
    led_flash_stop();
    return (result < 0) ? ERR_OTHER : result;
}

DirEnumCtx SDCardVFS::direnum(const char *path) {
    FF_DIR dir;
    if (f_opendir(&dir, path) != F_OK) {
        return nullptr;
    }

    auto result = std::make_shared<std::vector<DirEnumEntry>>();

    // Read directory contents
    FILINFO fno;
    while (1) {
        if (f_readdir(&dir, &fno) != FR_OK || fno.fname[0] == 0) {
            // Done
            break;
        }

        // Skip hidden and system files
        if ((fno.fattrib & (AM_SYS | AM_HID)))
            continue;

        result->emplace_back(fno.fname, fno.fsize, (fno.fattrib & AM_DIR) ? DE_DIR : 0, fno.fdate, fno.ftime);
    }

    // Close directory
    f_closedir(&dir);

    return result;
}

int SDCardVFS::delete_(const char *path) {
    char *full_path = get_fullpath(path);

    led_flash_start();
    int result = unlink(full_path);
    if (result < 0) {
        result = rmdir(full_path);
    }
    led_flash_stop();
    int err_no = errno;
    free(full_path);

    if (result < 0) {
        // Error
        if (err_no == ENOTEMPTY) {
            return ERR_NOT_EMPTY;
        } else {
            return ERR_NOT_FOUND;
        }
    }
    return 0;
}

int SDCardVFS::rename(const char *path_old, const char *path_new) {
    char *full_old = get_fullpath(path_old);
    char *full_new = get_fullpath(path_new);

    led_flash_start();
    int result = ::rename(full_old, full_new);
    led_flash_stop();
    free(full_old);
    free(full_new);

    return (result < 0) ? ERR_NOT_FOUND : 0;
}

int SDCardVFS::mkdir(const char *path) {
    char *full_path = get_fullpath(path);

    led_flash_start();
    int result = ::mkdir(full_path, 0775);
    led_flash_stop();
    free(full_path);

    return (result < 0) ? ERR_OTHER : 0;
}

int SDCardVFS::stat(const char *path, struct stat *st) {
    char *full_path = get_fullpath(path);
    led_flash_start();
    int result = ::stat(full_path, st);
    led_flash_stop();
    free(full_path);

    return result < 0 ? ERR_NOT_FOUND : 0;
}
