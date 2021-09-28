import axios, { AxiosError } from "axios";
import schedule from "node-schedule";

import dayjs from "dayjs";
import weekOfYear from "dayjs/plugin/weekOfYear";
dayjs.extend(weekOfYear);

// Import schedules.json here
const configs: {
	[id: string]: {
		channelName: string;
		messageTemplate: string;
		messages: string[];
		selectionType: string;
		schedule: string;
	};
} = require("./schedules.json");

const getChannelId = async (channelName: string): Promise<string | null> => {
	return axios
		.get(
			`https://mm.codebots.com/api/v4/teams/s8n7gnf3c7yg7yssdqi7kjemco/channels/name/${channelName}`,
			{
				headers: {
					Authorization: "Bearer " + process.env.PERSONAL_ACCESS_TOKEN,
				},
			}
		)
		.then((res) => {
			return res.data.id;
		})
		.catch((err: Error | AxiosError) => {
			console.error(err.message);
			console.warn("Could not find channel with id: " + channelName);

			return null;
		});
};

const getMessage = (scheduleName: string) => {
	const scheduleConfig = configs[scheduleName];

	let selectedPhrase: string;
	if (scheduleConfig.selectionType === "in order") {
		const weekOfYear = dayjs().week();

		selectedPhrase =
			scheduleConfig.messages[weekOfYear % scheduleConfig.messages.length];
	} else if (scheduleConfig.selectionType === "random") {
		selectedPhrase =
			scheduleConfig.messages[
				Math.floor(Math.random() * scheduleConfig.messages.length)
			];
	}

	return scheduleConfig.messageTemplate.replace("{message}", selectedPhrase);
};

const sendMessage = async (channelName: string, message: string) => {
	const channelId = await getChannelId(channelName).catch((err) => {
		console.log(err);
	});

	if (!channelId) return;

	axios
		.post(
			"https://mm.codebots.com/api/v4/posts",
			{
				channel_id: channelId,
				message: message,
			},
			{
				headers: {
					Authorization: "Bearer " + process.env.PERSONAL_ACCESS_TOKEN,
				},
			}
		)
		.then(() => {
			console.log("----------------");
			console.log("Sent scheduled message!");
			console.log(`Channel Name: ${channelName}`);
			console.log(`Message: ${message}`);
			console.log("----------------\n");
		});
};

// ----- Initialise schedules -----

function init() {
	Object.keys(configs).forEach((scheduleConfig) => {
		const cronSchedule = configs[scheduleConfig].schedule;
		const channelName = configs[scheduleConfig].channelName;

		schedule.scheduleJob(cronSchedule, async () => {
			const message = getMessage(scheduleConfig);
			sendMessage(channelName, message);
		});
	});

	console.log("Running...");

	// Run forever TODO: Replace this with something less hacky
	setInterval(() => {}, 1 << 30);
}

init();
