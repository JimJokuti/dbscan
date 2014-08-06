/*
SQLyog Ultimate v11.11 (64 bit)
MySQL - 5.1.47-enterprise-gpl-advanced-log : Database - dbscan
*********************************************************************
*/

/*!40101 SET NAMES utf8 */;

/*!40101 SET SQL_MODE=''*/;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
-- CREATE DATABASE /*!32312 IF NOT EXISTS*/`dbscan` /*!40100 DEFAULT CHARACTER SET utf8 */;

-- USE `dbscan`;

/*Table structure for table `dbhost` */

DROP TABLE IF EXISTS `dbhost`;

CREATE TABLE `dbhost` (
  `fqdn` varchar(128) NOT NULL DEFAULT '',
  `vip` varchar(32) DEFAULT NULL,
  `subnet` varchar(32) DEFAULT NULL,
  UNIQUE KEY `fqdn` (`fqdn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

/*Table structure for table `sc_instance` */

DROP TABLE IF EXISTS `sc_instance`;

CREATE TABLE `sc_instance` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `ipaddr` varchar(16) NOT NULL,
  `ipaddrint` bigint(20) DEFAULT NULL,
  `hostname` varchar(32) DEFAULT NULL,
  `mysql_version_num` varchar(32) DEFAULT NULL,
  `mysql_version_int` bigint(20) DEFAULT NULL,
  `mysql_version_type` varchar(128) DEFAULT NULL,
  `mysql_version_comment` varchar(128) DEFAULT NULL,
  `mysql_version_arch` varchar(32) DEFAULT NULL,
  `mysql_version_os` varchar(32) DEFAULT NULL,
  `portnum` int(8) DEFAULT NULL,
  `subnet` varchar(16) DEFAULT NULL,
  `subnetint` bigint(20) DEFAULT NULL,
  `checkflag` enum('Y','N') DEFAULT 'Y',
  `notes` varchar(256) DEFAULT NULL,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idu_ip_port` (`ipaddr`,`portnum`),
  KEY `idx_subnet` (`subnet`),
  KEY `idx_subnetint` (`subnetint`)
) ENGINE=InnoDB AUTO_INCREMENT=1598 DEFAULT CHARSET=utf8;

/*Table structure for table `sc_mycnf` */

DROP TABLE IF EXISTS `sc_mycnf`;

CREATE TABLE `sc_mycnf` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `iid` int(11) unsigned NOT NULL,
  `keyname` varchar(128) DEFAULT NULL,
  `val` text,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idu_iid_keyname` (`iid`,`keyname`),
  KEY `idx_iid` (`iid`),
  KEY `idx_keyname` (`keyname`)
) ENGINE=InnoDB AUTO_INCREMENT=11422 DEFAULT CHARSET=utf8;

/*Table structure for table `sc_mysql_version` */

DROP TABLE IF EXISTS `sc_mysql_version`;

CREATE TABLE `sc_mysql_version` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `mysql_version` varchar(16) NOT NULL,
  `note` varchar(128) DEFAULT NULL,
  `num_instances` int(11) DEFAULT NULL,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idu_version` (`mysql_version`)
) ENGINE=InnoDB AUTO_INCREMENT=129 DEFAULT CHARSET=utf8;

/*Table structure for table `sc_subnet` */

DROP TABLE IF EXISTS `sc_subnet`;

CREATE TABLE `sc_subnet` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `subnet` varchar(15) NOT NULL,
  `addrclass` enum('A','B','C') NOT NULL DEFAULT 'C',
  `description` varchar(128) DEFAULT NULL,
  `subnetint` bigint(20) DEFAULT NULL,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=52 DEFAULT CHARSET=utf8;

/*Table structure for table `sc_variable` */

DROP TABLE IF EXISTS `sc_variable`;

CREATE TABLE `sc_variable` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `iid` int(11) unsigned NOT NULL,
  `keyname` varchar(128) DEFAULT NULL,
  `val` text,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idu_iid_keyname` (`iid`,`keyname`),
  KEY `idx_iid` (`iid`),
  KEY `idx_keyname` (`keyname`)
) ENGINE=InnoDB AUTO_INCREMENT=454522 DEFAULT CHARSET=utf8;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
