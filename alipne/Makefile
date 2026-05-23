.PHONY: all prepare rootfs bootloader cleanup pack test clean help

all: prepare rootfs bootloader cleanup pack
	@echo "✓ 构建完成！镜像位于 output/alipne.qcow2"

prepare:
	@echo "==> 准备宿主机环境..."
	@bash scripts/01-prepare-host.sh

rootfs:
	@echo "==> 构建根文件系统..."
	@bash scripts/02-build-rootfs.sh

bootloader:
	@echo "==> 安装 grub 引导..."
	@bash scripts/03-setup-bootloader.sh

cleanup:
	@echo "==> 精简清理..."
	@bash scripts/04-cleanup.sh

pack:
	@echo "==> 打包 qcow2 镜像..."
	@bash scripts/05-pack-image.sh

test:
	@echo "==> 启动 QEMU 测试..."
	@bash scripts/06-test-image.sh

clean:
	@echo "==> 清理构建产物..."
	@rm -rf output/alipne.raw output/alipne.qcow2
	@rm -rf /tmp/alipne-build-*
	@echo "✓ 清理完成"

help:
	@echo "alipne - 极简 Alpine Linux 系统镜像构建"
	@echo ""
	@echo "用法:"
	@echo "  make all         一键构建完整镜像"
	@echo "  make prepare     准备宿主机环境"
	@echo "  make rootfs      构建根文件系统"
	@echo "  make bootloader  安装 grub"
	@echo "  make cleanup     精简清理"
	@echo "  make pack        打包 qcow2"
	@echo "  make test        QEMU 测试"
	@echo "  make clean       清理构建产物"
	@echo "  make help        显示此帮助"
